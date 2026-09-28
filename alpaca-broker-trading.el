;;; alpaca-broker-trading.el --- Trading-API account/reference endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Maintainer: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca trading-API client (https://api.alpaca.markets or
;; https://paper-api.alpaca.markets): account info, account
;; configurations, account activities, portfolio history, assets,
;; option contracts, the deprecated v2 corporate-action announcements,
;; the market calendar, and the market clock.
;;
;; Order placement/replacement/cancellation, position closing, and
;; option exercise live in `alpaca-broker-orders.el'; watchlist CRUD
;; lives in `alpaca-broker-watchlists.el'; crypto funding wallets live
;; in `alpaca-broker-wallets.el' -- none of those are read-only, so none
;; of them belong in this file.  Every function in *this* file is a
;; plain read; none of it is gated by `alpaca-broker-allow-orders'.
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form (takes
;; CALLBACK as its last required argument) and a synchronous
;; `alpaca-broker-FOO-sync' form, same convention as the rest of this
;; package.  Endpoints whose response paginates also have an
;; `alpaca-broker-FOO-all-sync' auto-paginating form.
;;
;; Requires `alpaca-broker.el' (this package's core: credentials, HTTP,
;; JSON, errors, and `alpaca-broker--trading-api-root', which honors
;; `alpaca-broker-paper') to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- account --

;;;###autoload
(defun alpaca-broker-account (callback)
  "Fetch the Alpaca trading account asynchronously and call CALLBACK.
Uses paper or live per `alpaca-broker-paper'.  CALLBACK is called with
the parsed JSON alist (Alpaca's raw `GET /v2/account' response --
`id', `status', `currency', `cash', `portfolio_value', ... )."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root)
   "GET"
   "/v2/account"
   nil
   nil
   callback))

(defun alpaca-broker-account-sync ()
  "Fetch and return the Alpaca trading account as a parsed JSON alist.
Synchronous form of `alpaca-broker-account'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/account"))

;; -- account configurations --

;;;###autoload
(defun alpaca-broker-account-configurations (callback)
  "Fetch the Alpaca account's trading configuration and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/account/configurations' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/account/configurations"
   nil nil callback))

(defun alpaca-broker-account-configurations-sync ()
  "Fetch and return the Alpaca account's trading configuration.
Synchronous form of `alpaca-broker-account-configurations'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/account/configurations"))

;;;###autoload
(defun alpaca-broker-update-account-configurations (updates callback)
  "Patch the Alpaca account's trading configuration and call CALLBACK.
UPDATES is an alist of the fields to change (any of
`disable_overnight_trading', `fractional_trading',
`max_margin_multiplier', `max_options_trading_level', `no_shorting',
`ptp_no_exception_entry', `suspend_trade', `trade_confirm_email').
CALLBACK is called with the parsed JSON alist (the updated
configuration).  Not order-mutating in the `alpaca-broker-allow-orders'
sense -- this changes account settings, not orders or positions."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "PATCH" "/v2/account/configurations"
   nil updates callback))

(defun alpaca-broker-update-account-configurations-sync (updates)
  "Patch and return the Alpaca account's trading configuration.
Synchronous form of `alpaca-broker-update-account-configurations'; see
it for UPDATES."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "PATCH" "/v2/account/configurations"
   nil updates))

;; -- account activities --

;;;###autoload
(defun alpaca-broker-account-activities (callback &optional params)
  "Fetch Alpaca account activities and call CALLBACK.
PARAMS is an optional alist of Alpaca's own `GET
/v2/account/activities' query parameters (`activity_types', `category',
`order_id', `date', `until', `after', `direction', `page_size',
`page_token'), passed straight through.  CALLBACK is called with the
raw parsed JSON list (a single page -- Alpaca paginates this endpoint
via `page_token'/the last item's `id', not `next_page_token'; see
`alpaca-broker-account-activities-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/account/activities"
   params nil callback))

(defun alpaca-broker-account-activities-sync (&optional params)
  "Fetch and return one page of Alpaca account activities.
Synchronous form of `alpaca-broker-account-activities'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/account/activities" params))

(defun alpaca-broker-account-activities-all-sync (&optional params)
  "Fetch and return every page of Alpaca account activities.
Auto-paginating form of `alpaca-broker-account-activities-sync'.  This
endpoint paginates via `page_token' set to the previous page's last
activity `id' (not `next_page_token'), so this does not use
`alpaca-broker--fetch-all-pages-sync'; it stops once a page comes back
with fewer entries than the requested `page_size' (default 100 when
PARAMS omits it)."
  (let* ((page-size
          (or (alist-get "page_size" params nil nil #'equal) "100"))
         (params (cons (cons "page_size" page-size)
                       (assoc-delete-all "page_size" (copy-alist params))))
         (acc nil) (token nil) (more t))
    (while more
      (let ((page (alpaca-broker-account-activities-sync
                    (cons (cons "page_token" token) params))))
        (setq acc (append acc page))
        (setq token (and page (alist-get 'id (car (last page)))))
        (setq more (and token (>= (length page) (string-to-number page-size))))))
    acc))

(defun alpaca-broker-account-activities-by-type (activity-type callback &optional params)
  "Fetch Alpaca account activities of ACTIVITY-TYPE and call CALLBACK.
ACTIVITY-TYPE is one of Alpaca's activity-type strings, e.g. \"FILL\"
or \"DIV\".  PARAMS as `alpaca-broker-account-activities', minus
`activity_types'/`category'.  CALLBACK is called with the raw parsed
JSON list (a single page)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/account/activities/%s" (url-hexify-string activity-type))
   params nil callback))

(defun alpaca-broker-account-activities-by-type-sync (activity-type &optional params)
  "Fetch and return one page of Alpaca account activities of ACTIVITY-TYPE.
Synchronous form of `alpaca-broker-account-activities-by-type'; see it
for ACTIVITY-TYPE/PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/account/activities/%s" (url-hexify-string activity-type))
   params))

;; -- portfolio history --

;;;###autoload
(defun alpaca-broker-portfolio-history (callback &optional params)
  "Fetch the Alpaca account's portfolio history and call CALLBACK.
PARAMS is an optional alist of Alpaca's own `GET
/v2/account/portfolio/history' query parameters (`period', `timeframe',
`intraday_reporting', `start', `pnl_reset', `end', `cashflow_types'),
passed straight through.  CALLBACK is called with the parsed JSON
alist (not paginated)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/account/portfolio/history"
   params nil callback))

(defun alpaca-broker-portfolio-history-sync (&optional params)
  "Fetch and return the Alpaca account's portfolio history.
Synchronous form of `alpaca-broker-portfolio-history'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/account/portfolio/history"
   params))

;; -- assets --

;;;###autoload
(defun alpaca-broker-assets (callback &optional params)
  "Fetch tradable Alpaca assets and call CALLBACK.
PARAMS is an optional alist of Alpaca's own `GET /v2/assets' query
parameters (`status', `asset_class', `exchange', `attributes'), passed
straight through.  CALLBACK is called with the parsed JSON list of
asset alists."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/assets" params nil callback))

(defun alpaca-broker-assets-sync (&optional params)
  "Fetch and return tradable Alpaca assets as a parsed JSON list.
Synchronous form of `alpaca-broker-assets'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/assets" params))

;;;###autoload
(defun alpaca-broker-asset (symbol-or-asset-id callback)
  "Fetch one Alpaca asset by SYMBOL-OR-ASSET-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/assets/SYMBOL-OR-ASSET-ID' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/assets/%s" (url-hexify-string symbol-or-asset-id))
   nil nil callback))

(defun alpaca-broker-asset-sync (symbol-or-asset-id)
  "Fetch and return one Alpaca asset by SYMBOL-OR-ASSET-ID.
Synchronous form of `alpaca-broker-asset'; see it for SYMBOL-OR-ASSET-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/assets/%s" (url-hexify-string symbol-or-asset-id))))

;; -- option contracts --

;;;###autoload
(defun alpaca-broker-option-contracts (callback &optional params)
  "Fetch Alpaca option contracts and call CALLBACK.
PARAMS is an optional alist of Alpaca's own `GET /v2/options/contracts'
query parameters (`underlying_symbols', `show_deliverables', `status',
`expiration_date', `expiration_date_gte', `expiration_date_lte',
`root_symbol', `type', `style', `strike_price_gte', `strike_price_lte',
`page_token', `limit', `ppind'), passed straight through.  CALLBACK is
called with the raw parsed JSON alist (a single page -- see
`alpaca-broker-option-contracts-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/options/contracts"
   params nil callback))

(defun alpaca-broker-option-contracts-sync (&optional params)
  "Fetch and return one page of Alpaca option contracts.
Synchronous form of `alpaca-broker-option-contracts'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/options/contracts" params))

(defun alpaca-broker-option-contracts-all-sync (&optional params)
  "Fetch and return every page of Alpaca option contracts.
Auto-paginating form of `alpaca-broker-option-contracts-sync';
PARAMS as there.  Returns
the merged list of option contracts across all pages."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-option-contracts-sync
      (cons (cons "page_token" token) params)))
   (lambda (acc page)
     (alpaca-broker--merge-flat-list-pages acc page 'option_contracts))))

;;;###autoload
(defun alpaca-broker-option-contract (symbol-or-id callback)
  "Fetch one Alpaca option contract by SYMBOL-OR-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/options/contracts/SYMBOL-OR-ID' response, including its
`deliverables' array)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/options/contracts/%s" (url-hexify-string symbol-or-id))
   nil nil callback))

(defun alpaca-broker-option-contract-sync (symbol-or-id)
  "Fetch and return one Alpaca option contract by SYMBOL-OR-ID.
Synchronous form of `alpaca-broker-option-contract'; see it for SYMBOL-OR-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/options/contracts/%s" (url-hexify-string symbol-or-id))))

;; -- corporate action announcements (deprecated v2, Trading API) --

;;;###autoload
(defun alpaca-broker-corporate-action-announcements (ca-types since until callback &optional params)
  "Fetch Trading-API corporate action announcements and call CALLBACK.
Deprecated by Alpaca in favor of the market-data corporate-actions
endpoint (`alpaca-broker-corporate-actions-sync' in
`alpaca-broker-data-misc.el'), but still live on the Trading API host,
so implemented here for full coverage.  CA-TYPES is a comma-joined
string or list of Alpaca's corporate-action-type strings (\"Spinoff\",
\"Merger\", \"Split\", \"Reorg\", \"Dividend\"); SINCE and UNTIL are
each a \"YYYY-MM-DD\" date string; all three are required by Alpaca.
PARAMS is an optional alist for the remaining query parameters
\(`symbol', `cusip', `date_type').  CALLBACK is called with the parsed
JSON list of announcement alists."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/corporate_actions/announcements"
   (append
    (list (cons "ca_types" (alpaca-broker--join-symbols ca-types))
          (cons "since" since)
          (cons "until" until))
    params)
   nil callback))

(defun alpaca-broker-corporate-action-announcements-sync (ca-types since until &optional params)
  "Fetch and return Trading-API corporate action announcements.
Synchronous form of `alpaca-broker-corporate-action-announcements'; see
it for CA-TYPES/SINCE/UNTIL/PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/corporate_actions/announcements"
   (append
    (list (cons "ca_types" (alpaca-broker--join-symbols ca-types))
          (cons "since" since)
          (cons "until" until))
    params)))

;;;###autoload
(defun alpaca-broker-corporate-action-announcement (id callback)
  "Fetch one Trading-API corporate action announcement by ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/corporate_actions/announcements/ID' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/corporate_actions/announcements/%s" (url-hexify-string id))
   nil nil callback))

(defun alpaca-broker-corporate-action-announcement-sync (id)
  "Fetch and return one Trading-API corporate action announcement by ID.
Synchronous form of `alpaca-broker-corporate-action-announcement'; see
it for ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/corporate_actions/announcements/%s" (url-hexify-string id))))

;; -- calendar --

;;;###autoload
(defun alpaca-broker-calendar (callback &optional params)
  "Fetch the Alpaca market calendar and call CALLBACK.
PARAMS is an optional alist (`start', `end', `date_type').  CALLBACK is
called with the parsed JSON list of calendar-day alists (Alpaca's raw
`GET /v2/calendar' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/calendar" params nil
   callback))

(defun alpaca-broker-calendar-sync (&optional params)
  "Fetch and return the Alpaca market calendar.
Synchronous form of `alpaca-broker-calendar'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/calendar" params))

;; -- clock --

;;;###autoload
(defun alpaca-broker-clock (callback)
  "Fetch the Alpaca market clock and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/clock' response -- `timestamp', `is_open', `next_open',
`next_close')."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/clock" nil nil callback))

(defun alpaca-broker-clock-sync ()
  "Fetch and return the Alpaca market clock.
Synchronous form of `alpaca-broker-clock'."
  (alpaca-broker--request-sync (alpaca-broker--trading-api-root) "GET" "/v2/clock"))

(provide 'alpaca-broker-trading)
;;; alpaca-broker-trading.el ends here
