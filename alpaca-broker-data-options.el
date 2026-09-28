;;; alpaca-broker-data-options.el --- Option market-data endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca's option market-data client
;; (https://data.alpaca.markets/v1beta1/options): historical bars and
;; trades, latest trades/quotes, snapshots, the option chain, and the
;; condition-code/exchange-code metadata endpoints.
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form (takes
;; CALLBACK as its last required argument) and a synchronous
;; `alpaca-broker-FOO-sync' form; paginated endpoints also have an
;; `alpaca-broker-FOO-all-sync' form -- same conventions as
;; `alpaca-broker-data-stocks.el'.
;;
;; SYMBOLS is an OSI option contract symbol or a comma-joined/list of
;; them (see `alpaca-broker--join-symbols').  Every fetcher accepts an
;; optional PARAMS alist for Alpaca's remaining query parameters (e.g.
;; `feed', which is \"opra\" or \"indicative\" -- OPRA requires an
;; options market-data subscription), passed straight through.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- historical bars --

;;;###autoload
(defun alpaca-broker-options-bars (symbols timeframe callback &optional params)
  "Fetch historical option bars for SYMBOLS at TIMEFRAME and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `page_token',
`sort').  CALLBACK is called with the raw parsed JSON alist (a single
page -- see `alpaca-broker-options-bars-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/options/bars"
   (append
    (list (cons "symbols" (alpaca-broker--join-symbols symbols))
          (cons "timeframe" timeframe))
    params)
   nil callback))

(defun alpaca-broker-options-bars-sync (symbols timeframe &optional params)
  "Fetch and return one page of historical option bars for SYMBOLS.
Synchronous form of `alpaca-broker-options-bars'; see it for
SYMBOLS/TIMEFRAME/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/options/bars"
   (append
    (list (cons "symbols" (alpaca-broker--join-symbols symbols))
          (cons "timeframe" timeframe))
    params)))

(defun alpaca-broker-options-bars-all-sync (symbols timeframe &optional params)
  "Fetch and return every page of historical option bars for SYMBOLS.
Auto-paginating form of `alpaca-broker-options-bars-sync';
SYMBOLS/TIMEFRAME/PARAMS as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-options-bars-sync
      symbols timeframe (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'bars))))

;; -- historical trades --

;;;###autoload
(defun alpaca-broker-options-trades (symbols callback &optional params)
  "Fetch historical option trades for SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`start', `end', `limit', `page_token',
`sort').  CALLBACK is called with the raw parsed JSON alist (a single
page -- see `alpaca-broker-options-trades-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/options/trades"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-options-trades-sync (symbols &optional params)
  "Fetch and return one page of historical option trades for SYMBOLS.
Synchronous form of `alpaca-broker-options-trades'; see it for SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/options/trades"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-options-trades-all-sync (symbols &optional params)
  "Fetch and return every page of historical option trades for SYMBOLS.
Auto-paginating form of `alpaca-broker-options-trades-sync';
PARAMS as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-options-trades-sync
      symbols (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'trades))))

;; -- latest --

;;;###autoload
(defun alpaca-broker-options-latest-trades (symbols callback &optional params)
  "Fetch the latest option trade for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed').  CALLBACK is called with the raw
parsed JSON alist (a `trades' key mapping contract symbol -> trade)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/options/trades/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-options-latest-trades-sync (symbols &optional params)
  "Fetch and return the latest option trade for each of SYMBOLS.
Synchronous form of `alpaca-broker-options-latest-trades'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/options/trades/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

;;;###autoload
(defun alpaca-broker-options-latest-quotes (symbols callback &optional params)
  "Fetch the latest option quote for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed').  CALLBACK is called with the raw
parsed JSON alist (a `quotes' key mapping contract symbol -> quote)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/options/quotes/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-options-latest-quotes-sync (symbols &optional params)
  "Fetch and return the latest option quote for each of SYMBOLS.
Synchronous form of `alpaca-broker-options-latest-quotes'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/options/quotes/latest"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

;; -- snapshots and chain --

;;;###autoload
(defun alpaca-broker-options-snapshots (symbols callback &optional params)
  "Fetch an option snapshot for each of SYMBOLS and call CALLBACK.
PARAMS is an optional alist (`feed', `updated_since', `limit',
`page_token').  CALLBACK is called with the raw parsed JSON alist (a
single page -- see `alpaca-broker-options-snapshots-all-sync' to fetch
every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/options/snapshots"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)
   nil callback))

(defun alpaca-broker-options-snapshots-sync (symbols &optional params)
  "Fetch and return one page of option snapshots for SYMBOLS.
Synchronous form of `alpaca-broker-options-snapshots'; see it for
SYMBOLS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/options/snapshots"
   (cons (cons "symbols" (alpaca-broker--join-symbols symbols)) params)))

(defun alpaca-broker-options-snapshots-all-sync (symbols &optional params)
  "Fetch and return every page of option snapshots for SYMBOLS.
Auto-paginating form of `alpaca-broker-options-snapshots-sync';
PARAMS as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-options-snapshots-sync
      symbols (cons (cons "page_token" token) params)))
   (lambda (acc page)
     (alpaca-broker--merge-keyed-object-pages acc page 'snapshots))))

;;;###autoload
(defun alpaca-broker-options-chain (underlying-symbol callback &optional params)
  "Fetch the option chain for UNDERLYING-SYMBOL and call CALLBACK.
PARAMS is an optional alist of Alpaca's own `GET
/v1beta1/options/snapshots/UNDERLYING-SYMBOL' query parameters
\(`feed', `limit', `updated_since', `page_token', `type', `strike_price_gte',
`strike_price_lte', `expiration_date', `expiration_date_gte',
`expiration_date_lte', `root_symbol').  CALLBACK is called with the raw
parsed JSON alist (a single page -- see
`alpaca-broker-options-chain-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/options/snapshots/%s"
           (url-hexify-string underlying-symbol))
   params nil callback))

(defun alpaca-broker-options-chain-sync (underlying-symbol &optional params)
  "Fetch and return one page of UNDERLYING-SYMBOL's option chain.
Synchronous form of `alpaca-broker-options-chain'; see it for
UNDERLYING-SYMBOL/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/options/snapshots/%s"
           (url-hexify-string underlying-symbol))
   params))

(defun alpaca-broker-options-chain-all-sync (underlying-symbol &optional params)
  "Fetch and return every page of UNDERLYING-SYMBOL's option chain.
Auto-paginating form of `alpaca-broker-options-chain-sync'; PARAMS
as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-options-chain-sync
      underlying-symbol (cons (cons "page_token" token) params)))
   (lambda (acc page)
     (alpaca-broker--merge-keyed-object-pages acc page 'snapshots))))

;; -- meta --

;;;###autoload
(defun alpaca-broker-options-condition-codes (tick-type callback)
  "Fetch option condition codes for TICK-TYPE and call CALLBACK.
TICK-TYPE is \"trade\" or \"quote\".  CALLBACK is called with the
parsed JSON alist (Alpaca's raw `GET
/v1beta1/options/meta/conditions/TICK-TYPE' response -- a flat map of
code to description)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/options/meta/conditions/%s"
           (url-hexify-string tick-type))
   nil nil callback))

(defun alpaca-broker-options-condition-codes-sync (tick-type)
  "Fetch and return option condition codes for TICK-TYPE.
Synchronous form of `alpaca-broker-options-condition-codes'; see it
for TICK-TYPE."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/options/meta/conditions/%s"
           (url-hexify-string tick-type))))

;;;###autoload
(defun alpaca-broker-options-exchange-codes (callback)
  "Fetch option exchange codes and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v1beta1/options/meta/exchanges' response -- a flat map of exchange
code to exchange name)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/options/meta/exchanges" nil
   nil callback))

(defun alpaca-broker-options-exchange-codes-sync ()
  "Fetch and return option exchange codes.
Synchronous form of `alpaca-broker-options-exchange-codes'."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/options/meta/exchanges"))

(provide 'alpaca-broker-data-options)
;;; alpaca-broker-data-options.el ends here
