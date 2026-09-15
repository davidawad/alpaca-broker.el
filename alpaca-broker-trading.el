;;; alpaca-broker-trading.el --- Read-only trading endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: Your Name <you@example.com>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca trading-API client (https://api.alpaca.markets or
;; https://paper-api.alpaca.markets), read-only v1 scope: account info,
;; open positions, and order history.  Deliberately does NOT implement
;; placing, replacing, or canceling orders -- see this package's
;; README.md roadmap section.
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form (takes
;; CALLBACK as its last required argument) and a synchronous
;; `alpaca-broker-FOO-sync' form (blocks and returns the parsed JSON
;; alist directly), same convention as `alpaca-broker-data.el'.
;;
;; Requires `alpaca-broker.el' (this package's core: credentials,
;; HTTP, JSON, errors, and `alpaca-broker--trading-api-root', which
;; honors `alpaca-broker-paper') to already be loaded or on
;; `load-path'.

;;; Code:

(require 'alpaca-broker)

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
   callback))

(defun alpaca-broker-account-sync ()
  "Fetch and return the Alpaca trading account as a parsed JSON alist.
Synchronous form of `alpaca-broker-account'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/account"))

;;;###autoload
(defun alpaca-broker-positions (callback)
  "Fetch every open Alpaca position asynchronously and call CALLBACK.
Uses paper or live per `alpaca-broker-paper'.  CALLBACK is called with
the parsed JSON list of position alists (Alpaca's raw `GET
/v2/positions' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root)
   "GET"
   "/v2/positions"
   nil
   callback))

(defun alpaca-broker-positions-sync ()
  "Fetch and return every open Alpaca position as a parsed JSON list.
Synchronous form of `alpaca-broker-positions'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/positions"))

;;;###autoload
(defun alpaca-broker-orders (callback &optional params)
  "Fetch Alpaca orders asynchronously and call CALLBACK.
Uses paper or live per `alpaca-broker-paper'.  PARAMS is an optional
alist of Alpaca's own `GET /v2/orders' query parameters, e.g.
`((\"status\" . \"all\") (\"limit\" . \"50\"))' -- string values only,
since it is passed straight through to `alpaca-broker--url'.  CALLBACK
is called with the parsed JSON list of order alists."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root)
   "GET"
   "/v2/orders"
   params
   callback))

(defun alpaca-broker-orders-sync (&optional params)
  "Fetch and return Alpaca orders as a parsed JSON list.
Synchronous form of `alpaca-broker-orders'; PARAMS is passed through
unchanged, see `alpaca-broker-orders'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/orders" params))

(provide 'alpaca-broker-trading)
;;; alpaca-broker-trading.el ends here
