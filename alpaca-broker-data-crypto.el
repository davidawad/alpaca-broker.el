;;; alpaca-broker-data-crypto.el --- Crypto market-data endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca's crypto market-data client
;; (https://data.alpaca.markets/v1beta3/crypto/{loc}): historical/latest
;; bars, trades, quotes, order books, and snapshots.
;;
;; Alpaca's crypto data endpoints identify symbols (e.g. "BTC/USD") via
;; a `symbols' query parameter rather than a URL path segment (crypto
;; symbols contain `/', which is not URL-path-safe), wrap the response
;; in a map keyed by symbol, and require a `loc' path segment selecting
;; the trading venue (default "us"; also "us-1", "us-2", "eu-1",
;; "bs-1").  `alpaca-broker--crypto-unwrap' pulls a single symbol's
;; entry out of a keyed response map.
;;
;; This file keeps three single-symbol convenience wrappers from the
;; original v1 API (`alpaca-broker-crypto-latest-quote',
;; `alpaca-broker-crypto-latest-trade', `alpaca-broker-crypto-bars'),
;; each calling the multi-symbol endpoint with one symbol and unwrapping
;; the result, plus new `-multi' functions exposing the raw
;; keyed-by-symbol response for every symbol requested.  Every fetcher
;; has an asynchronous `alpaca-broker-FOO' form and a synchronous
;; `alpaca-broker-FOO-sync' form; paginated endpoints also have an
;; `alpaca-broker-FOO-all-sync' form.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

(defconst alpaca-broker--crypto-api-prefix "/v1beta3/crypto"
  "Path prefix for Alpaca's crypto market-data endpoints, sans `/LOC'.")

(defun alpaca-broker--crypto-path (loc suffix)
  "Return the crypto market-data path for LOC (default \"us\") and SUFFIX."
  (format "%s/%s%s" alpaca-broker--crypto-api-prefix (or loc "us") suffix))

(defun alpaca-broker--crypto-unwrap (response wrapper-key symbol)
  "Extract SYMBOL's entry from RESPONSE's WRAPPER-KEY map.
Alpaca wraps crypto responses as e.g. `{\"quotes\":
{\"BTC/USD\": {...}}}'; WRAPPER-KEY would be `quotes' and SYMBOL would
be \"BTC/USD\".  Returns nil if RESPONSE, its WRAPPER-KEY map, or
SYMBOL's entry in it is absent."
  (alist-get (intern symbol) (alist-get wrapper-key response)))

;; -- historical bars --

;;;###autoload
(defun alpaca-broker-crypto-bars
    (symbol timeframe callback &optional start end limit loc)
  "Fetch SYMBOL's historical crypto bars at TIMEFRAME and call CALLBACK.
SYMBOL is e.g. \"BTC/USD\".  Optionally windowed by START/END (each an
ISO-8601 string) and capped at LIMIT bars.  LOC selects the venue
\(default \"us\").  CALLBACK is called with SYMBOL's list of bars,
already unwrapped from Alpaca's per-symbol response map via
`alpaca-broker--crypto-unwrap'."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (alpaca-broker--crypto-path loc "/bars")
   (append
    (list (cons "symbols" symbol) (cons "timeframe" timeframe))
    (alpaca-broker--bars-params start end limit))
   nil
   (lambda (response)
     (funcall callback
              (alpaca-broker--crypto-unwrap response 'bars symbol)))))

(defun alpaca-broker-crypto-bars-sync
    (symbol timeframe &optional start end limit loc)
  "Fetch and return SYMBOL's historical crypto bars at TIMEFRAME.
Synchronous form of `alpaca-broker-crypto-bars'; see it for
START/END/LIMIT/LOC.  Returns a list."
  (alpaca-broker--crypto-unwrap
   (alpaca-broker--request-sync
    alpaca-broker--data-api-root
    "GET"
    (alpaca-broker--crypto-path loc "/bars")
    (append
     (list (cons "symbols" symbol) (cons "timeframe" timeframe))
     (alpaca-broker--bars-params start end limit)))
   'bars symbol))

;;;###autoload
(defun alpaca-broker-crypto-bars-multi
    (symbols timeframe callback &optional params loc)
  "Fetch historical crypto bars for SYMBOLS at TIMEFRAME and call CALLBACK.
SYMBOLS is comma-joined or a list, see `alpaca-broker--join-symbols'.
PARAMS is an optional alist (`start', `end', `limit', `page_token',
`sort').  LOC selects the venue (default \"us\").  CALLBACK is called
with the raw parsed JSON alist, keyed by symbol -- a single page, see
`alpaca-broker-crypto-bars-multi-all-sync' to fetch every page."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" (alpaca-broker--crypto-path loc "/bars")
   (append
    (list (cons "symbols" (alpaca-broker--join-symbols symbols))
          (cons "timeframe" timeframe))
    params)
   nil callback))

(defun alpaca-broker-crypto-bars-multi-sync (symbols timeframe &optional params loc)
  "Fetch and return one page of historical crypto bars for SYMBOLS.
Synchronous form of `alpaca-broker-crypto-bars-multi'; see it for
SYMBOLS/TIMEFRAME/PARAMS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" (alpaca-broker--crypto-path loc "/bars")
   (append
    (list (cons "symbols" (alpaca-broker--join-symbols symbols))
          (cons "timeframe" timeframe))
    params)))

(defun alpaca-broker-crypto-bars-multi-all-sync
    (symbols timeframe &optional params loc)
  "Fetch and return every page of historical crypto bars for SYMBOLS.
Auto-paginating form of `alpaca-broker-crypto-bars-multi-sync';
SYMBOLS/TIMEFRAME/PARAMS/LOC as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-crypto-bars-multi-sync
      symbols timeframe (cons (cons "page_token" token) params) loc))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'bars))))

;;;###autoload
(defun alpaca-broker-crypto-latest-bars-multi (symbols callback &optional loc)
  "Fetch the latest crypto bar for each of SYMBOLS and call CALLBACK.
LOC selects the venue (default \"us\").  CALLBACK is called with the
raw parsed JSON alist, a `bars' key mapping symbol -> bar."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/bars")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols))) nil callback))

(defun alpaca-broker-crypto-latest-bars-multi-sync (symbols &optional loc)
  "Fetch and return the latest crypto bar for each of SYMBOLS.
Synchronous form of `alpaca-broker-crypto-latest-bars-multi'; see it
for SYMBOLS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/bars")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols)))))

;; -- historical trades --

;;;###autoload
(defun alpaca-broker-crypto-trades-multi (symbols callback &optional params loc)
  "Fetch historical crypto trades for SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `page_token',
`sort').  LOC selects the venue (default \"us\").  CALLBACK is called
with the raw parsed JSON alist (a single page -- see
`alpaca-broker-crypto-trades-multi-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" (alpaca-broker--crypto-path loc "/trades")
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-crypto-trades-multi-sync (symbols &optional params loc)
  "Fetch and return one page of historical crypto trades for SYMBOLS.
Synchronous form of `alpaca-broker-crypto-trades-multi'; see it for
SYMBOLS/PARAMS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" (alpaca-broker--crypto-path loc "/trades")
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-crypto-trades-multi-all-sync (symbols &optional params loc)
  "Fetch and return every page of historical crypto trades for SYMBOLS.
Auto-paginating form of `alpaca-broker-crypto-trades-multi-sync';
SYMBOLS/PARAMS/LOC as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-crypto-trades-multi-sync
      symbols (cons (cons "page_token" token) params) loc))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'trades))))

;;;###autoload
(defun alpaca-broker-crypto-latest-trade (symbol callback &optional loc)
  "Fetch SYMBOL's latest crypto trade asynchronously and call CALLBACK.
SYMBOL is e.g. \"BTC/USD\".  LOC selects the venue (default \"us\").
CALLBACK is called with SYMBOL's trade alist, already unwrapped from
Alpaca's per-symbol response map via `alpaca-broker--crypto-unwrap'."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (alpaca-broker--crypto-path loc "/latest/trades")
   `(("symbols" . ,symbol))
   nil
   (lambda (response)
     (funcall
      callback
      (alpaca-broker--crypto-unwrap response 'trades symbol)))))

(defun alpaca-broker-crypto-latest-trade-sync (symbol &optional loc)
  "Fetch and return SYMBOL's latest crypto trade alist.
Synchronous form of `alpaca-broker-crypto-latest-trade'; see it for
SYMBOL/LOC."
  (alpaca-broker--crypto-unwrap
   (alpaca-broker--request-sync
    alpaca-broker--data-api-root
    "GET"
    (alpaca-broker--crypto-path loc "/latest/trades")
    `(("symbols" . ,symbol)))
   'trades symbol))

;;;###autoload
(defun alpaca-broker-crypto-latest-trades-multi (symbols callback &optional loc)
  "Fetch the latest crypto trade for each of SYMBOLS and call CALLBACK.
LOC selects the venue (default \"us\").  CALLBACK is called with the
raw parsed JSON alist, a `trades' key mapping symbol -> trade."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/trades")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols))) nil callback))

(defun alpaca-broker-crypto-latest-trades-multi-sync (symbols &optional loc)
  "Fetch and return the latest crypto trade for each of SYMBOLS.
Synchronous form of `alpaca-broker-crypto-latest-trades-multi'; see it
for SYMBOLS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/trades")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols)))))

;; -- historical quotes --

;;;###autoload
(defun alpaca-broker-crypto-latest-quote (symbol callback &optional loc)
  "Fetch SYMBOL's latest crypto quote asynchronously and call CALLBACK.
SYMBOL is e.g. \"BTC/USD\".  LOC selects the venue (default \"us\").
CALLBACK is called with SYMBOL's quote alist, already unwrapped from
Alpaca's per-symbol response map via `alpaca-broker--crypto-unwrap'."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (alpaca-broker--crypto-path loc "/latest/quotes")
   `(("symbols" . ,symbol))
   nil
   (lambda (response)
     (funcall
      callback
      (alpaca-broker--crypto-unwrap response 'quotes symbol)))))

(defun alpaca-broker-crypto-latest-quote-sync (symbol &optional loc)
  "Fetch and return SYMBOL's latest crypto quote alist.
Synchronous form of `alpaca-broker-crypto-latest-quote'; see it for
SYMBOL/LOC."
  (alpaca-broker--crypto-unwrap
   (alpaca-broker--request-sync
    alpaca-broker--data-api-root
    "GET"
    (alpaca-broker--crypto-path loc "/latest/quotes")
    `(("symbols" . ,symbol)))
   'quotes symbol))

;;;###autoload
(defun alpaca-broker-crypto-quotes-multi (symbols callback &optional params loc)
  "Fetch historical crypto quotes for SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `page_token',
`sort').  LOC selects the venue (default \"us\").  CALLBACK is called
with the raw parsed JSON alist (a single page -- see
`alpaca-broker-crypto-quotes-multi-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" (alpaca-broker--crypto-path loc "/quotes")
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-crypto-quotes-multi-sync (symbols &optional params loc)
  "Fetch and return one page of historical crypto quotes for SYMBOLS.
Synchronous form of `alpaca-broker-crypto-quotes-multi'; see it for
SYMBOLS/PARAMS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" (alpaca-broker--crypto-path loc "/quotes")
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-crypto-quotes-multi-all-sync (symbols &optional params loc)
  "Fetch and return every page of historical crypto quotes for SYMBOLS.
Auto-paginating form of `alpaca-broker-crypto-quotes-multi-sync';
SYMBOLS/PARAMS/LOC as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-crypto-quotes-multi-sync
      symbols (cons (cons "page_token" token) params) loc))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'quotes))))

;;;###autoload
(defun alpaca-broker-crypto-latest-quotes-multi (symbols callback &optional loc)
  "Fetch the latest crypto quote for each of SYMBOLS and call CALLBACK.
LOC selects the venue (default \"us\").  CALLBACK is called with the
raw parsed JSON alist, a `quotes' key mapping symbol -> quote."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/quotes")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols))) nil callback))

(defun alpaca-broker-crypto-latest-quotes-multi-sync (symbols &optional loc)
  "Fetch and return the latest crypto quote for each of SYMBOLS.
Synchronous form of `alpaca-broker-crypto-latest-quotes-multi'; see it
for SYMBOLS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/quotes")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols)))))

;; -- order books and snapshots --

;;;###autoload
(defun alpaca-broker-crypto-latest-orderbooks-multi (symbols callback &optional loc)
  "Fetch the latest crypto order book for each of SYMBOLS and call CALLBACK.
LOC selects the venue (default \"us\").  CALLBACK is called with the
raw parsed JSON alist, an `orderbooks' key mapping symbol -> book."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/orderbooks")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols))) nil callback))

(defun alpaca-broker-crypto-latest-orderbooks-multi-sync (symbols &optional loc)
  "Fetch and return the latest crypto order book for each of SYMBOLS.
Synchronous form of `alpaca-broker-crypto-latest-orderbooks-multi'; see
it for SYMBOLS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/latest/orderbooks")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols)))))

;;;###autoload
(defun alpaca-broker-crypto-snapshots-multi (symbols callback &optional loc)
  "Fetch a crypto snapshot for each of SYMBOLS and call CALLBACK.
LOC selects the venue (default \"us\").  CALLBACK is called with the
raw parsed JSON alist, a `snapshots' key mapping symbol -> snapshot."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/snapshots")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols))) nil callback))

(defun alpaca-broker-crypto-snapshots-multi-sync (symbols &optional loc)
  "Fetch and return a crypto snapshot for each of SYMBOLS.
Synchronous form of `alpaca-broker-crypto-snapshots-multi'; see it for
SYMBOLS/LOC."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (alpaca-broker--crypto-path loc "/snapshots")
   `(("symbols" . ,(alpaca-broker--join-symbols symbols)))))

(provide 'alpaca-broker-data-crypto)
;;; alpaca-broker-data-crypto.el ends here
