;;; alpaca-broker-data.el --- Market-data endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: Your Name <you@example.com>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca market-data client (https://data.alpaca.markets): latest
;; quotes, latest trades, and historical bars, for both stocks and
;; crypto.  Every fetcher has two forms:
;;
;;   `alpaca-broker-FOO'      -- asynchronous, takes a CALLBACK as its
;;                               last required argument, called with
;;                               the parsed JSON alist.
;;   `alpaca-broker-FOO-sync' -- synchronous, blocks up to
;;                               `alpaca-broker-timeout' seconds and
;;                               returns the parsed JSON alist
;;                               directly.
;;
;; Also provides `alpaca-broker-show-quote', a small interactive demo
;; command.
;;
;; Requires `alpaca-broker.el' (this package's core: credentials,
;; HTTP, JSON, errors) to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- stocks --

;;;###autoload
(defun alpaca-broker-latest-quote (symbol callback)
  "Fetch SYMBOL's latest stock quote asynchronously and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/SYMBOL/quotes/latest' response -- a `symbol' key and a
`quote' key holding the bid/ask alist) on success."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/quotes/latest" (url-hexify-string symbol))
   nil
   callback))

(defun alpaca-broker-latest-quote-sync (symbol)
  "Fetch and return SYMBOL's latest stock quote as a parsed JSON alist.
Synchronous form of `alpaca-broker-latest-quote'."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/quotes/latest" (url-hexify-string symbol))))

;;;###autoload
(defun alpaca-broker-latest-trade (symbol callback)
  "Fetch SYMBOL's latest stock trade asynchronously and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/SYMBOL/trades/latest' response) on success."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/trades/latest" (url-hexify-string symbol))
   nil
   callback))

(defun alpaca-broker-latest-trade-sync (symbol)
  "Fetch and return SYMBOL's latest stock trade as a parsed JSON alist.
Synchronous form of `alpaca-broker-latest-trade'."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/trades/latest" (url-hexify-string symbol))))

(defun alpaca-broker--bars-params (start end limit)
  "Build the query-params alist shared by the bars fetchers.
START and END are each an optional ISO-8601 string; LIMIT is an
optional integer, converted to a string."
  `(("start" . ,start)
    ("end" . ,end)
    ("limit" . ,(and limit (number-to-string limit)))))

;;;###autoload
(defun alpaca-broker-bars
    (symbol timeframe callback &optional start end limit)
  "Fetch SYMBOL's historical stock bars at TIMEFRAME and call CALLBACK.
TIMEFRAME is one of Alpaca's own timeframe strings, e.g. \"1Min\",
\"15Min\", \"1Day\".  Optionally windowed by START/END (each an
ISO-8601 string) and capped at LIMIT bars.  CALLBACK is called with
the parsed JSON alist (Alpaca's raw `GET /v2/stocks/SYMBOL/bars'
response -- a `bars' key holding the list) on success."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/bars" (url-hexify-string symbol))
   (cons
    (cons "timeframe" timeframe)
    (alpaca-broker--bars-params start end limit))
   callback))

(defun alpaca-broker-bars-sync
    (symbol timeframe &optional start end limit)
  "Fetch and return SYMBOL's historical stock bars at TIMEFRAME.
Synchronous form of `alpaca-broker-bars'; see it for START/END/LIMIT.
Returns the parsed JSON alist."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/bars" (url-hexify-string symbol))
   (cons
    (cons "timeframe" timeframe)
    (alpaca-broker--bars-params start end limit))))

;; -- crypto --
;;
;; Alpaca's crypto data endpoints identify symbols (e.g. "BTC/USD") via
;; a `symbols' query parameter rather than a URL path segment (crypto
;; symbols contain `/', which is not URL-path-safe), and wrap the
;; response in a map keyed by symbol -- `alpaca-broker--crypto-unwrap'
;; below pulls a single symbol's entry out of that map.

(defconst alpaca-broker--crypto-api-prefix "/v1beta3/crypto/us"
  "Path prefix for Alpaca's US crypto market-data endpoints.")

(defun alpaca-broker--crypto-unwrap (response wrapper-key symbol)
  "Extract SYMBOL's entry from RESPONSE's WRAPPER-KEY map.
Alpaca wraps crypto responses as e.g. `{\"quotes\":
{\"BTC/USD\": {...}}}'; WRAPPER-KEY would be `quotes' and SYMBOL would
be \"BTC/USD\".  Returns nil if RESPONSE, its WRAPPER-KEY map, or
SYMBOL's entry in it is absent."
  (alist-get (intern symbol) (alist-get wrapper-key response)))

;;;###autoload
(defun alpaca-broker-crypto-latest-quote (symbol callback)
  "Fetch SYMBOL's latest crypto quote asynchronously and call CALLBACK.
SYMBOL is e.g. \"BTC/USD\".  CALLBACK is called with SYMBOL's quote
alist, already unwrapped from Alpaca's per-symbol response map via
`alpaca-broker--crypto-unwrap'."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (concat alpaca-broker--crypto-api-prefix "/latest/quotes")
   `(("symbols" . ,symbol))
   (lambda (response)
     (funcall
      callback
      (alpaca-broker--crypto-unwrap response 'quotes symbol)))))

(defun alpaca-broker-crypto-latest-quote-sync (symbol)
  "Fetch and return SYMBOL's latest crypto quote alist.
Synchronous form of `alpaca-broker-crypto-latest-quote'."
  (alpaca-broker--crypto-unwrap
   (alpaca-broker--request-sync
    alpaca-broker--data-api-root
    "GET"
    (concat alpaca-broker--crypto-api-prefix "/latest/quotes")
    `(("symbols" . ,symbol)))
   'quotes symbol))

;;;###autoload
(defun alpaca-broker-crypto-latest-trade (symbol callback)
  "Fetch SYMBOL's latest crypto trade asynchronously and call CALLBACK.
SYMBOL is e.g. \"BTC/USD\".  CALLBACK is called with SYMBOL's trade
alist, already unwrapped from Alpaca's per-symbol response map via
`alpaca-broker--crypto-unwrap'."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (concat alpaca-broker--crypto-api-prefix "/latest/trades")
   `(("symbols" . ,symbol))
   (lambda (response)
     (funcall
      callback
      (alpaca-broker--crypto-unwrap response 'trades symbol)))))

(defun alpaca-broker-crypto-latest-trade-sync (symbol)
  "Fetch and return SYMBOL's latest crypto trade alist.
Synchronous form of `alpaca-broker-crypto-latest-trade'."
  (alpaca-broker--crypto-unwrap
   (alpaca-broker--request-sync
    alpaca-broker--data-api-root
    "GET"
    (concat alpaca-broker--crypto-api-prefix "/latest/trades")
    `(("symbols" . ,symbol)))
   'trades symbol))

;;;###autoload
(defun alpaca-broker-crypto-bars
    (symbol timeframe callback &optional start end limit)
  "Fetch SYMBOL's historical crypto bars at TIMEFRAME and call CALLBACK.
SYMBOL is e.g. \"BTC/USD\".  Optionally windowed by START/END (each an
ISO-8601 string) and capped at LIMIT bars.  CALLBACK is called with
SYMBOL's list of bars, already unwrapped from Alpaca's per-symbol
response map via `alpaca-broker--crypto-unwrap'."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (concat alpaca-broker--crypto-api-prefix "/bars")
   (append
    (list (cons "symbols" symbol) (cons "timeframe" timeframe))
    (alpaca-broker--bars-params start end limit))
   (lambda (response)
     (funcall callback
              (alpaca-broker--crypto-unwrap response 'bars symbol)))))

(defun alpaca-broker-crypto-bars-sync
    (symbol timeframe &optional start end limit)
  "Fetch and return SYMBOL's historical crypto bars at TIMEFRAME.
Synchronous form of `alpaca-broker-crypto-bars'; see it for
START/END/LIMIT.  Returns a list."
  (alpaca-broker--crypto-unwrap
   (alpaca-broker--request-sync
    alpaca-broker--data-api-root
    "GET"
    (concat alpaca-broker--crypto-api-prefix "/bars")
    (append
     (list (cons "symbols" symbol) (cons "timeframe" timeframe))
     (alpaca-broker--bars-params start end limit)))
   'bars symbol))

;; -- demo command --

;;;###autoload
(defun alpaca-broker-show-quote (symbol)
  "Prompt for a stock SYMBOL and show its latest bid/ask quote.
Displayed in the minibuffer.  A small, visible demo of
`alpaca-broker-latest-quote-sync' -- see
`alpaca-broker-crypto-latest-quote-sync' for the crypto equivalent."
  (interactive "sAlpaca symbol: ")
  (let* ((response (alpaca-broker-latest-quote-sync symbol))
         (quote (alist-get 'quote response)))
    (if quote
        (message "%s: bid %s x%s / ask %s x%s"
                 (or (alist-get 'symbol response) symbol)
                 (alist-get 'bp quote)
                 (alist-get 'bs quote)
                 (alist-get 'ap quote)
                 (alist-get 'as quote))
      (message "Alpaca: no quote returned for %s" symbol))))

(provide 'alpaca-broker-data)
;;; alpaca-broker-data.el ends here
