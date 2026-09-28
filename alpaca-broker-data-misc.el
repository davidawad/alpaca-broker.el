;;; alpaca-broker-data-misc.el --- Remaining market-data endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; The remaining Alpaca market-data endpoints that don't warrant their
;; own file: forex rates (https://data.alpaca.markets/v1beta1/forex),
;; fixed-income latest prices/quotes
;; (https://data.alpaca.markets/v1beta1/fixed_income), the stock/crypto
;; screener (https://data.alpaca.markets/v1beta1/screener), symbol
;; logos (https://data.alpaca.markets/v1beta1/logos), and the
;; market-data flavor of corporate actions
;; (https://data.alpaca.markets/v1/corporate-actions -- the successor to
;; the deprecated Trading-API `/v2/corporate_actions/announcements',
;; see `alpaca-broker-trading.el').
;;
;; Every fetcher follows this package's usual async/`-sync' convention;
;; paginated endpoints also have an `-all-sync' auto-paginating form.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- forex --

;;;###autoload
(defun alpaca-broker-forex-rates (currency-pairs callback &optional params)
  "Fetch historical forex rates for CURRENCY-PAIRS and call CALLBACK.
CURRENCY-PAIRS is comma-joined or a list, e.g. \"EUR/USD\" or
\(\"EUR/USD\" \"GBP/USD\").  PARAMS is an optional alist (`timeframe',
`start', `end', `limit', `sort', `page_token').  CALLBACK is called
with the raw parsed JSON alist (a single page -- see
`alpaca-broker-forex-rates-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/forex/rates"
   (cons (cons "currency_pairs" (alpaca-broker--join-symbols currency-pairs))
         params)
   nil callback))

(defun alpaca-broker-forex-rates-sync (currency-pairs &optional params)
  "Fetch and return one page of historical forex rates for CURRENCY-PAIRS.
Synchronous form of `alpaca-broker-forex-rates'; see it for
CURRENCY-PAIRS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/forex/rates"
   (cons (cons "currency_pairs" (alpaca-broker--join-symbols currency-pairs))
         params)))

(defun alpaca-broker-forex-rates-all-sync (currency-pairs &optional params)
  "Fetch and return every page of historical forex rates for CURRENCY-PAIRS.
Auto-paginating form of `alpaca-broker-forex-rates-sync'; PARAMS
as there."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-forex-rates-sync
      currency-pairs (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-keyed-list-pages acc page 'rates))))

;;;###autoload
(defun alpaca-broker-forex-latest-rates (currency-pairs callback)
  "Fetch the latest forex rate for each of CURRENCY-PAIRS and call CALLBACK.
CURRENCY-PAIRS is comma-joined or a list.  CALLBACK is called with the
raw parsed JSON alist, a `rates' key mapping pair -> rate."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/forex/latest/rates"
   `(("currency_pairs" . ,(alpaca-broker--join-symbols currency-pairs)))
   nil callback))

(defun alpaca-broker-forex-latest-rates-sync (currency-pairs)
  "Fetch and return the latest forex rate for each of CURRENCY-PAIRS.
Synchronous form of `alpaca-broker-forex-latest-rates'; see it for
CURRENCY-PAIRS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/forex/latest/rates"
   `(("currency_pairs" . ,(alpaca-broker--join-symbols currency-pairs)))))

;; -- fixed income --

;;;###autoload
(defun alpaca-broker-fixed-income-latest-prices (isins callback)
  "Fetch the latest fixed-income price for each of ISINS and call CALLBACK.
ISINS is comma-joined or a list.  CALLBACK is called with the raw
parsed JSON alist (Alpaca's raw `GET
/v1beta1/fixed_income/latest/prices' response -- a `prices' key
mapping ISIN -> price)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/fixed_income/latest/prices"
   `(("isins" . ,(alpaca-broker--join-symbols isins))) nil callback))

(defun alpaca-broker-fixed-income-latest-prices-sync (isins)
  "Fetch and return the latest fixed-income price for each of ISINS.
Synchronous form of `alpaca-broker-fixed-income-latest-prices'; see it
for ISINS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/fixed_income/latest/prices"
   `(("isins" . ,(alpaca-broker--join-symbols isins)))))

;;;###autoload
(defun alpaca-broker-fixed-income-latest-quotes (isins callback &optional params)
  "Fetch the latest fixed-income quote for each of ISINS and call CALLBACK.
ISINS is comma-joined or a list.  PARAMS is an optional alist
\(`trade_size').  CALLBACK is called with the raw parsed JSON alist (a
`quotes' key mapping ISIN -> quote)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/fixed_income/latest/quotes"
   (cons (cons "isins" (alpaca-broker--join-symbols isins)) params)
   nil callback))

(defun alpaca-broker-fixed-income-latest-quotes-sync (isins &optional params)
  "Fetch and return the latest fixed-income quote for each of ISINS.
Synchronous form of `alpaca-broker-fixed-income-latest-quotes'; see it
for ISINS/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/fixed_income/latest/quotes"
   (cons (cons "isins" (alpaca-broker--join-symbols isins)) params)))

;; -- screener --

;;;###autoload
(defun alpaca-broker-screener-most-actives (callback &optional params)
  "Fetch the most-active stocks by volume/trade-count and call CALLBACK.
PARAMS is an optional alist (`by' -- \"volume\" or \"trades\", `top').
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v1beta1/screener/stocks/most-actives' response)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/screener/stocks/most-actives"
   params nil callback))

(defun alpaca-broker-screener-most-actives-sync (&optional params)
  "Fetch and return the most-active stocks by volume/trade-count.
Synchronous form of `alpaca-broker-screener-most-actives'; see it for PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/screener/stocks/most-actives"
   params))

;;;###autoload
(defun alpaca-broker-screener-movers (market-type callback &optional params)
  "Fetch top gainers/losers for MARKET-TYPE and call CALLBACK.
MARKET-TYPE is \"stocks\" or \"crypto\".  PARAMS is an optional alist
\(`top').  CALLBACK is called with the parsed JSON alist (Alpaca's raw
`GET /v1beta1/screener/MARKET-TYPE/movers' response -- `gainers' and
`losers' keys)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/screener/%s/movers" (url-hexify-string market-type))
   params nil callback))

(defun alpaca-broker-screener-movers-sync (market-type &optional params)
  "Fetch and return top gainers/losers for MARKET-TYPE.
Synchronous form of `alpaca-broker-screener-movers'; see it for
MARKET-TYPE/PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/screener/%s/movers" (url-hexify-string market-type))
   params))

;; -- logos --

;;;###autoload
(defun alpaca-broker-logo-sync (symbol &optional placeholder)
  "Fetch and return SYMBOL's logo image as a raw PNG byte string.
PLACEHOLDER, when non-nil, requests Alpaca's placeholder image instead
of an empty response when no logo exists for SYMBOL (Alpaca's own
default); pass `:false' explicitly to request the opposite.  Synchronous
only -- there is no async form, since the response is a binary image,
not JSON, and no CALLBACK-based unmarshalling applies.  Note per
Alpaca's docs: Logo API pricing is by sales inquiry, so this endpoint
may be unavailable on standard market-data plans."
  (alpaca-broker--request-sync-binary
   alpaca-broker--data-api-root "GET"
   (format "/v1beta1/logos/%s" (url-hexify-string symbol))
   (and placeholder
        `(("placeholder" . ,(if (eq placeholder :false) "false" "true"))))))

;; -- corporate actions (market-data flavor) --

;;;###autoload
(defun alpaca-broker-corporate-actions (callback &optional params)
  "Fetch corporate actions and call CALLBACK.
The market-data flavor of corporate actions (`GET
/v1/corporate-actions' on the market-data host) -- the successor to
the deprecated Trading-API `/v2/corporate_actions/announcements' (see
`alpaca-broker-corporate-action-announcements-sync' in
`alpaca-broker-trading.el').  PARAMS is an optional alist of Alpaca's
own query parameters (`symbols', `cusips', `types', `region', `start',
`end', `ids', `limit', `data_quality', `page_token', `sort'), passed
straight through.  CALLBACK is called with the raw parsed JSON alist
-- a `corporate_actions' key holding one array per corporate-action
type (`cash_dividends', `forward_splits', ... ) -- a single page, see
`alpaca-broker-corporate-actions-all-sync' to fetch every page."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1/corporate-actions" params nil
   callback))

(defun alpaca-broker-corporate-actions-sync (&optional params)
  "Fetch and return one page of corporate actions.
Synchronous form of `alpaca-broker-corporate-actions'; see it for PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1/corporate-actions" params))

(defun alpaca-broker--merge-corporate-actions-pages (acc page)
  "Merge PAGE's `corporate_actions' sub-collections into ACC.
MERGE-FN for `alpaca-broker--fetch-all-pages-sync' on
`alpaca-broker-corporate-actions-sync' -- unlike the other market-data
list endpoints, each page nests many typed arrays (`cash_dividends',
`forward_splits', ...) under one `corporate_actions' key, so every
sub-collection is concatenated independently."
  (let ((page-cas (alist-get 'corporate_actions page)))
    (dolist (entry page-cas)
      (let* ((type (car entry))
             (items (cdr entry))
             (existing (assq type acc)))
        (if existing
            (setcdr existing (append (cdr existing) items))
          (push (cons type items) acc))))
    acc))

(defun alpaca-broker-corporate-actions-all-sync (&optional params)
  "Fetch and return every page of corporate actions.
Auto-paginating form of `alpaca-broker-corporate-actions-sync';
PARAMS as there.  Returns
the merged `corporate_actions' alist (type -> list) across all pages."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-corporate-actions-sync
      (cons (cons "page_token" token) params)))
   #'alpaca-broker--merge-corporate-actions-pages))

(provide 'alpaca-broker-data-misc)
;;; alpaca-broker-data-misc.el ends here
