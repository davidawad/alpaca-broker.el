;;; alpaca-broker-data-stocks.el --- Stock market-data endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca's stock market-data client (https://data.alpaca.markets/v2/stocks):
;; historical/latest bars, trades, quotes, snapshots, auctions, and the
;; condition-code/exchange-code metadata endpoints.  Plus
;; `alpaca-broker-show-quote', a small interactive demo command.
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form (takes
;; CALLBACK as its last required argument) and a synchronous
;; `alpaca-broker-FOO-sync' form (blocks and returns the parsed JSON
;; alist directly), same convention as the rest of this package.
;; Endpoints whose response paginates via `next_page_token' also have an
;; `alpaca-broker-FOO-all-sync' form that fetches every page and merges
;; them via `alpaca-broker--fetch-all-pages-sync'.
;;
;; Single-symbol endpoints (`/v2/stocks/{symbol}/...') take SYMBOL as a
;; string.  Multi-symbol endpoints (`/v2/stocks/...' with a `symbols'
;; query param) take SYMBOLS, either a comma-joined string or a list of
;; strings (see `alpaca-broker--join-symbols'), and their PARAMS alist
;; carries every other optional query parameter Alpaca documents for
;; that endpoint (e.g. `(("start" . "2024-01-01T00:00:00Z") ("feed" .
;; "iex"))') -- passed straight through, same convention as
;; `alpaca-broker-orders'.
;;
;; Requires `alpaca-broker.el' (this package's core: credentials, HTTP,
;; JSON, errors, pagination) to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- historical bars --

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
   nil
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

;;;###autoload
(defun alpaca-broker-stocks-bars (symbols timeframe callback &optional params)
  "Fetch historical stock bars for SYMBOLS at TIMEFRAME and call CALLBACK.
SYMBOLS is comma-joined or a list, see `alpaca-broker--join-symbols'.
PARAMS is an optional alist of Alpaca's own `GET /v2/stocks/bars' query
parameters (`start', `end', `limit', `adjustment', `asof', `feed',
`currency', `page_token', `sort'), passed straight through.  CALLBACK
is called with the raw parsed JSON alist (a single page -- see
`alpaca-broker-stocks-bars-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/bars"
   (append
    (list (cons "symbols" (alpaca-broker--join-symbols symbols))
          (cons "timeframe" timeframe))
    params)
   nil callback))

(defun alpaca-broker-stocks-bars-sync (symbols timeframe &optional params)
  "Fetch and return one page of historical stock bars for SYMBOLS.
Synchronous form of `alpaca-broker-stocks-bars'; see it for
SYMBOLS/TIMEFRAME/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/bars"
   (append
    (list (cons "symbols" (alpaca-broker--join-symbols symbols))
          (cons "timeframe" timeframe))
    params)))

(defun alpaca-broker-stocks-bars-all-sync (symbols timeframe &optional params)
  "Fetch and return every page of historical stock bars for SYMBOLS.
Auto-paginating form of `alpaca-broker-stocks-bars-sync'; SYMBOLS,
TIMEFRAME, and PARAMS as there.  Returns the merged `bars' alist
\(symbol -> list of bars) across all pages."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-stocks-bars-sync
      symbols timeframe
      (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'bars))))

;;;###autoload
(defun alpaca-broker-latest-bar (symbol callback &optional params)
  "Fetch SYMBOL's latest stock minute bar asynchronously and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/SYMBOL/bars/latest' response)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/bars/latest" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-latest-bar-sync (symbol &optional params)
  "Fetch and return SYMBOL's latest stock minute bar.
Synchronous form of `alpaca-broker-latest-bar'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/bars/latest" (url-hexify-string symbol)) params))

;;;###autoload
(defun alpaca-broker-stocks-latest-bars (symbols callback &optional params)
  "Fetch the latest stock minute bar for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the raw parsed JSON alist (a `bars' key mapping symbol -> bar)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/bars/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-latest-bars-sync (symbols &optional params)
  "Fetch and return the latest stock minute bar for each of SYMBOLS.
Synchronous form of `alpaca-broker-stocks-latest-bars'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/bars/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

;; -- historical trades --

;;;###autoload
(defun alpaca-broker-trades (symbol callback &optional params)
  "Fetch SYMBOL's historical stock trades and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `asof', `feed',
`currency', `page_token', `sort').  CALLBACK is called with the raw
parsed JSON alist (a single page -- see `alpaca-broker-trades-all-sync'
to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/trades" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-trades-sync (symbol &optional params)
  "Fetch and return one page of SYMBOL's historical stock trades.
Synchronous form of `alpaca-broker-trades'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/trades" (url-hexify-string symbol)) params))

(defun alpaca-broker-trades-all-sync (symbol &optional params)
  "Fetch and return every page of SYMBOL's historical stock trades.
Auto-paginating form of `alpaca-broker-trades-sync'; PARAMS as
there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-trades-sync symbol (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-flat-list-pages acc page 'trades))))

;;;###autoload
(defun alpaca-broker-stocks-trades (symbols callback &optional params)
  "Fetch historical stock trades for SYMBOLS and call CALLBACK.
PARAMS as `alpaca-broker-trades'.  CALLBACK is called with the raw
parsed JSON alist (a single page -- see
`alpaca-broker-stocks-trades-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/trades"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-trades-sync (symbols &optional params)
  "Fetch and return one page of historical stock trades for SYMBOLS.
Synchronous form of `alpaca-broker-stocks-trades'; see it for SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/trades"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-stocks-trades-all-sync (symbols &optional params)
  "Fetch and return every page of historical stock trades for SYMBOLS.
Auto-paginating form of `alpaca-broker-stocks-trades-sync'; PARAMS
as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-stocks-trades-sync
      symbols (cons (cons "page_token" token) params)))
   (lambda (acc page)
     (alpaca-broker--merge-keyed-list-pages acc page 'trades))))

;;;###autoload
(defun alpaca-broker-latest-trade (symbol callback &optional params)
  "Fetch SYMBOL's latest stock trade asynchronously and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/SYMBOL/trades/latest' response) on success."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/trades/latest" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-latest-trade-sync (symbol &optional params)
  "Fetch and return SYMBOL's latest stock trade as a parsed JSON alist.
Synchronous form of `alpaca-broker-latest-trade'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/trades/latest" (url-hexify-string symbol)) params))

;;;###autoload
(defun alpaca-broker-stocks-latest-trades (symbols callback &optional params)
  "Fetch the latest stock trade for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the raw parsed JSON alist (a `trades' key mapping symbol -> trade)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/trades/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-latest-trades-sync (symbols &optional params)
  "Fetch and return the latest stock trade for each of SYMBOLS.
Synchronous form of `alpaca-broker-stocks-latest-trades'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/trades/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

;; -- historical quotes --

;;;###autoload
(defun alpaca-broker-latest-quote (symbol callback &optional params)
  "Fetch SYMBOL's latest stock quote asynchronously and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/SYMBOL/quotes/latest' response -- a `symbol' key and a
`quote' key holding the bid/ask alist) on success."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/quotes/latest" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-latest-quote-sync (symbol &optional params)
  "Fetch and return SYMBOL's latest stock quote as a parsed JSON alist.
Synchronous form of `alpaca-broker-latest-quote'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root
   "GET"
   (format "/v2/stocks/%s/quotes/latest" (url-hexify-string symbol)) params))

;;;###autoload
(defun alpaca-broker-quotes (symbol callback &optional params)
  "Fetch SYMBOL's historical stock quotes (NBBO) and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `asof', `feed',
`currency', `page_token', `sort').  CALLBACK is called with the raw
parsed JSON alist (a single page -- see `alpaca-broker-quotes-all-sync'
to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/quotes" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-quotes-sync (symbol &optional params)
  "Fetch and return one page of SYMBOL's historical stock quotes.
Synchronous form of `alpaca-broker-quotes'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/quotes" (url-hexify-string symbol)) params))

(defun alpaca-broker-quotes-all-sync (symbol &optional params)
  "Fetch and return every page of SYMBOL's historical stock quotes.
Auto-paginating form of `alpaca-broker-quotes-sync'; PARAMS as
there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-quotes-sync symbol (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-flat-list-pages acc page 'quotes))))

;;;###autoload
(defun alpaca-broker-stocks-quotes (symbols callback &optional params)
  "Fetch historical stock quotes (NBBO) for SYMBOLS and call CALLBACK.
PARAMS as `alpaca-broker-quotes'.  CALLBACK is called with the raw
parsed JSON alist (a single page -- see
`alpaca-broker-stocks-quotes-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/quotes"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-quotes-sync (symbols &optional params)
  "Fetch and return one page of historical stock quotes for SYMBOLS.
Synchronous form of `alpaca-broker-stocks-quotes'; see it for SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/quotes"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-stocks-quotes-all-sync (symbols &optional params)
  "Fetch and return every page of historical stock quotes for SYMBOLS.
Auto-paginating form of `alpaca-broker-stocks-quotes-sync'; PARAMS
as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-stocks-quotes-sync
      symbols (cons (cons "page_token" token) params)))
   (lambda (acc page)
     (alpaca-broker--merge-keyed-list-pages acc page 'quotes))))

;;;###autoload
(defun alpaca-broker-stocks-latest-quotes (symbols callback &optional params)
  "Fetch the latest stock quote for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the raw parsed JSON alist (a `quotes' key mapping symbol -> quote)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/quotes/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-latest-quotes-sync (symbols &optional params)
  "Fetch and return the latest stock quote for each of SYMBOLS.
Synchronous form of `alpaca-broker-stocks-latest-quotes'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/quotes/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

;; -- snapshots --

;;;###autoload
(defun alpaca-broker-snapshot (symbol callback &optional params)
  "Fetch SYMBOL's stock snapshot and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  A snapshot bundles
the latest trade, latest quote, minute bar, daily bar, and previous
daily bar in one response.  CALLBACK is called with the parsed JSON
alist (Alpaca's raw `GET /v2/stocks/SYMBOL/snapshot' response)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/snapshot" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-snapshot-sync (symbol &optional params)
  "Fetch and return SYMBOL's stock snapshot.
Synchronous form of `alpaca-broker-snapshot'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/snapshot" (url-hexify-string symbol)) params))

;;;###autoload
(defun alpaca-broker-stocks-snapshots (symbols callback &optional params)
  "Fetch a stock snapshot for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed', `currency').  CALLBACK is called
with the raw parsed JSON alist, an object keyed by symbol -> snapshot."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/snapshots"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-snapshots-sync (symbols &optional params)
  "Fetch and return a stock snapshot for each of SYMBOLS.
Synchronous form of `alpaca-broker-stocks-snapshots'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/snapshots"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

;; -- auctions --

;;;###autoload
(defun alpaca-broker-auctions (symbol callback &optional params)
  "Fetch SYMBOL's historical opening/closing auctions and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `asof', `feed'
-- only \"sip\" is valid, `currency', `page_token', `sort').  CALLBACK
is called with the raw parsed JSON alist (a single page -- see
`alpaca-broker-auctions-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/auctions" (url-hexify-string symbol))
   params nil callback))

(defun alpaca-broker-auctions-sync (symbol &optional params)
  "Fetch and return one page of SYMBOL's historical auctions.
Synchronous form of `alpaca-broker-auctions'; see it for SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/%s/auctions" (url-hexify-string symbol)) params))

(defun alpaca-broker-auctions-all-sync (symbol &optional params)
  "Fetch and return every page of SYMBOL's historical auctions.
Auto-paginating form of `alpaca-broker-auctions-sync'; PARAMS as
there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-auctions-sync symbol (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-flat-list-pages acc page 'auctions))))

;;;###autoload
(defun alpaca-broker-stocks-auctions (symbols callback &optional params)
  "Fetch historical opening/closing auctions for SYMBOLS and call CALLBACK.
PARAMS as `alpaca-broker-auctions'.  CALLBACK is called with the raw
parsed JSON alist (a single page -- see
`alpaca-broker-stocks-auctions-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/auctions"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-stocks-auctions-sync (symbols &optional params)
  "Fetch and return one page of historical auctions for SYMBOLS.
Synchronous form of `alpaca-broker-stocks-auctions'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/auctions"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-stocks-auctions-all-sync (symbols &optional params)
  "Fetch and return every page of historical auctions for SYMBOLS.
Auto-paginating form of `alpaca-broker-stocks-auctions-sync';
PARAMS as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-stocks-auctions-sync
      symbols (cons (cons "page_token" token) params)))
   (lambda (acc page)
     (alpaca-broker--merge-keyed-list-pages acc page 'auctions))))

;; -- meta --

;;;###autoload
(defun alpaca-broker-stocks-condition-codes (tick-type tape callback)
  "Fetch stock condition codes for TICK-TYPE/TAPE and call CALLBACK.
TICK-TYPE is \"trade\" or \"quote\"; TAPE is \"A\", \"B\", or \"C\".
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/meta/conditions/TICK-TYPE' response -- a flat map of code
to description)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/meta/conditions/%s" (url-hexify-string tick-type))
   `(("tape" . ,tape)) nil callback))

(defun alpaca-broker-stocks-condition-codes-sync (tick-type tape)
  "Fetch and return stock condition codes for TICK-TYPE/TAPE.
Synchronous form of `alpaca-broker-stocks-condition-codes'; see it for
TICK-TYPE/TAPE."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v2/stocks/meta/conditions/%s" (url-hexify-string tick-type))
   `(("tape" . ,tape))))

;;;###autoload
(defun alpaca-broker-stocks-exchange-codes (callback)
  "Fetch stock exchange codes and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/stocks/meta/exchanges' response -- a flat map of exchange code to
exchange name)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v2/stocks/meta/exchanges" nil nil
   callback))

(defun alpaca-broker-stocks-exchange-codes-sync ()
  "Fetch and return stock exchange codes.
Synchronous form of `alpaca-broker-stocks-exchange-codes'."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v2/stocks/meta/exchanges"))

;; -- demo command --

;;;###autoload
(defun alpaca-broker-show-quote (symbol)
  "Prompt for a stock SYMBOL and show its latest bid/ask quote.
Displayed in the minibuffer.  A small, visible demo of
`alpaca-broker-latest-quote-sync'."
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

(provide 'alpaca-broker-data-stocks)
;;; alpaca-broker-data-stocks.el ends here
