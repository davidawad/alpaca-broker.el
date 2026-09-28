;;; alpaca-broker-orders.el --- Order and position endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Maintainer: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca trading-API order and position endpoints
;; (https://api.alpaca.markets or https://paper-api.alpaca.markets):
;; list/get orders, place/replace/cancel orders, list/get/close
;; positions, and exercise/decline-exercise option positions.
;;
;; Every function that PLACES, REPLACES, or CANCELS an order, CLOSES a
;; position, or EXERCISES/DECLINES an option contract calls
;; `alpaca-broker--require-order-permission' first, which signals a
;; `user-error' unless the defcustom `alpaca-broker-allow-orders' is
;; non-nil.  It defaults to nil, so this file can be loaded and its
;; read-only functions used freely without ever risking an accidental
;; mutation; flip `alpaca-broker-allow-orders' explicitly (and keep
;; `alpaca-broker-paper' non-nil, its own default, while doing so) to
;; enable order placement.
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form (takes
;; CALLBACK as its last required argument) and a synchronous
;; `alpaca-broker-FOO-sync' form, same convention as the rest of this
;; package.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- orders: read --

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
   nil
   callback))

(defun alpaca-broker-orders-sync (&optional params)
  "Fetch and return Alpaca orders as a parsed JSON list.
Synchronous form of `alpaca-broker-orders'; PARAMS is passed through
unchanged, see `alpaca-broker-orders'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/orders" params))

;;;###autoload
(defun alpaca-broker-order (order-id callback &optional params)
  "Fetch one Alpaca order by ORDER-ID and call CALLBACK.
PARAMS is an optional alist (`nested').  CALLBACK is called with the
parsed JSON alist (Alpaca's raw `GET /v2/orders/ORDER-ID' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/orders/%s" (url-hexify-string order-id))
   params nil callback))

(defun alpaca-broker-order-sync (order-id &optional params)
  "Fetch and return one Alpaca order by ORDER-ID.
Synchronous form of `alpaca-broker-order'; see it for ORDER-ID/PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/orders/%s" (url-hexify-string order-id)) params))

;;;###autoload
(defun alpaca-broker-order-by-client-id (client-order-id callback)
  "Fetch one Alpaca order by CLIENT-ORDER-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/orders:by_client_order_id' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/orders:by_client_order_id"
   `(("client_order_id" . ,client-order-id)) nil callback))

(defun alpaca-broker-order-by-client-id-sync (client-order-id)
  "Fetch and return one Alpaca order by CLIENT-ORDER-ID.
Synchronous form of `alpaca-broker-order-by-client-id'; see it for
CLIENT-ORDER-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/orders:by_client_order_id"
   `(("client_order_id" . ,client-order-id))))

;; -- orders: mutate (gated) --

;;;###autoload
(defun alpaca-broker-create-order (order callback)
  "Submit ORDER to Alpaca asynchronously and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
ORDER is an alist of Alpaca's own `POST /v2/orders' request-body
fields, e.g. `((\"symbol\" . \"SPY\") (\"qty\" . \"1\") (\"side\" .
\"buy\") (\"type\" . \"limit\") (\"time_in_force\" . \"day\")
\(\"limit_price\" . \"1.00\"))'.  CALLBACK is called with the parsed
JSON alist for the created order."
  (alpaca-broker--require-order-permission 'alpaca-broker-create-order)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST" "/v2/orders" nil order callback))

(defun alpaca-broker-create-order-sync (order)
  "Submit ORDER to Alpaca and return the created order.
Synchronous form of `alpaca-broker-create-order'; see it for ORDER and
the `alpaca-broker-allow-orders' gate."
  (alpaca-broker--require-order-permission 'alpaca-broker-create-order-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST" "/v2/orders" nil order))

;;;###autoload
(defun alpaca-broker-replace-order (order-id updates callback)
  "Replace Alpaca order ORDER-ID with UPDATES and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
UPDATES is an alist of Alpaca's own `PATCH /v2/orders/ORDER-ID'
request-body fields (`client_order_id', `qty', `notional',
`limit_price', `stop_price', `trail', `time_in_force',
`advanced_instructions').  CALLBACK is called with the parsed JSON
alist for the replacement order (a new order id)."
  (alpaca-broker--require-order-permission 'alpaca-broker-replace-order)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "PATCH"
   (format "/v2/orders/%s" (url-hexify-string order-id))
   nil updates callback))

(defun alpaca-broker-replace-order-sync (order-id updates)
  "Replace Alpaca order ORDER-ID with UPDATES and return the new order.
Synchronous form of `alpaca-broker-replace-order'; see it for UPDATES
and the `alpaca-broker-allow-orders' gate."
  (alpaca-broker--require-order-permission 'alpaca-broker-replace-order-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "PATCH"
   (format "/v2/orders/%s" (url-hexify-string order-id)) nil updates))

;;;###autoload
(defun alpaca-broker-cancel-order (order-id callback)
  "Cancel Alpaca order ORDER-ID asynchronously and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
CALLBACK is called with nil on success (Alpaca returns 204 No
Content)."
  (alpaca-broker--require-order-permission 'alpaca-broker-cancel-order)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/orders/%s" (url-hexify-string order-id))
   nil nil callback))

(defun alpaca-broker-cancel-order-sync (order-id)
  "Cancel Alpaca order ORDER-ID.
Synchronous form of `alpaca-broker-cancel-order'.  Signals a
`user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission 'alpaca-broker-cancel-order-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/orders/%s" (url-hexify-string order-id))))

;;;###autoload
(defun alpaca-broker-cancel-all-orders (callback)
  "Cancel every open Alpaca order asynchronously and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
CALLBACK is called with the parsed JSON list of `{id, status}' results,
one per order Alpaca attempted to cancel (207 Multi-Status)."
  (alpaca-broker--require-order-permission 'alpaca-broker-cancel-all-orders)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE" "/v2/orders" nil nil callback))

(defun alpaca-broker-cancel-all-orders-sync ()
  "Cancel every open Alpaca order and return the per-order results.
Synchronous form of `alpaca-broker-cancel-all-orders'.  Signals a
`user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission 'alpaca-broker-cancel-all-orders-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE" "/v2/orders"))

;; -- positions: read --

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
   nil
   callback))

(defun alpaca-broker-positions-sync ()
  "Fetch and return every open Alpaca position as a parsed JSON list.
Synchronous form of `alpaca-broker-positions'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/positions"))

;;;###autoload
(defun alpaca-broker-position (symbol-or-asset-id callback)
  "Fetch one open Alpaca position by SYMBOL-OR-ASSET-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist (Alpaca's raw `GET
/v2/positions/SYMBOL-OR-ASSET-ID' response)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/positions/%s" (url-hexify-string symbol-or-asset-id))
   nil nil callback))

(defun alpaca-broker-position-sync (symbol-or-asset-id)
  "Fetch and return one open Alpaca position by SYMBOL-OR-ASSET-ID.
Synchronous form of `alpaca-broker-position'; see it for SYMBOL-OR-ASSET-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/positions/%s" (url-hexify-string symbol-or-asset-id))))

;; -- positions: mutate (gated) --

;;;###autoload
(defun alpaca-broker-close-position (symbol-or-asset-id callback &optional params)
  "Close Alpaca position SYMBOL-OR-ASSET-ID asynchronously and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
PARAMS is an optional alist (`qty' or `percentage', mutually
exclusive).  CALLBACK is called with the parsed JSON alist for the
order Alpaca created to close the position."
  (alpaca-broker--require-order-permission 'alpaca-broker-close-position)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/positions/%s" (url-hexify-string symbol-or-asset-id))
   params nil callback))

(defun alpaca-broker-close-position-sync (symbol-or-asset-id &optional params)
  "Close Alpaca position SYMBOL-OR-ASSET-ID and return the closing order.
Synchronous form of `alpaca-broker-close-position'; PARAMS as
there.  Signals a
`user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission 'alpaca-broker-close-position-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/positions/%s" (url-hexify-string symbol-or-asset-id)) params))

;;;###autoload
(defun alpaca-broker-close-all-positions (callback &optional params)
  "Close every open Alpaca position asynchronously and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
PARAMS is an optional alist (`cancel_orders').  CALLBACK is called with
the parsed JSON list of `{symbol, status, body}' results, one per
position Alpaca attempted to close (207 Multi-Status)."
  (alpaca-broker--require-order-permission 'alpaca-broker-close-all-positions)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE" "/v2/positions" params nil
   callback))

(defun alpaca-broker-close-all-positions-sync (&optional params)
  "Close every open Alpaca position and return the per-position results.
Synchronous form of `alpaca-broker-close-all-positions'; PARAMS as
there.  Signals a
`user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission 'alpaca-broker-close-all-positions-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE" "/v2/positions" params))

;; -- options exercise (gated) --

;;;###autoload
(defun alpaca-broker-exercise-position (symbol-or-contract-id callback)
  "Exercise held option position SYMBOL-OR-CONTRACT-ID and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
Exercises all available held quantity.  Requests between market close
and midnight are rejected by Alpaca.  CALLBACK is called with nil on
success (200, empty body)."
  (alpaca-broker--require-order-permission 'alpaca-broker-exercise-position)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST"
   (format "/v2/positions/%s/exercise"
           (url-hexify-string symbol-or-contract-id))
   nil nil callback))

(defun alpaca-broker-exercise-position-sync (symbol-or-contract-id)
  "Exercise held option position SYMBOL-OR-CONTRACT-ID.
Synchronous form of `alpaca-broker-exercise-position'.  Signals a
`user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission 'alpaca-broker-exercise-position-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST"
   (format "/v2/positions/%s/exercise"
           (url-hexify-string symbol-or-contract-id))))

;;;###autoload
(defun alpaca-broker-decline-exercise-position (symbol-or-contract-id callback)
  "Submit a do-not-exercise instruction for SYMBOL-OR-CONTRACT-ID.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
Overrides Alpaca's default auto-exercise of in-the-money contracts at
expiry.  CALLBACK is called with nil on success (200, empty body)."
  (alpaca-broker--require-order-permission
   'alpaca-broker-decline-exercise-position)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST"
   (format "/v2/positions/%s/do-not-exercise"
           (url-hexify-string symbol-or-contract-id))
   nil nil callback))

(defun alpaca-broker-decline-exercise-position-sync (symbol-or-contract-id)
  "Submit a do-not-exercise instruction for SYMBOL-OR-CONTRACT-ID.
Synchronous form of `alpaca-broker-decline-exercise-position'.  Signals
a `user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission
   'alpaca-broker-decline-exercise-position-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST"
   (format "/v2/positions/%s/do-not-exercise"
           (url-hexify-string symbol-or-contract-id))))

(provide 'alpaca-broker-orders)
;;; alpaca-broker-orders.el ends here
