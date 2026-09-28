;;; alpaca-broker-watchlists.el --- Watchlist endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Maintainer: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca trading-API watchlist endpoints
;; (https://api.alpaca.markets or https://paper-api.alpaca.markets):
;; full CRUD, both by watchlist id (`/v2/watchlists/{watchlist_id}')
;; and by name (`/v2/watchlists:by_name').
;;
;; Watchlists are not orders or positions -- creating, renaming, or
;; deleting one never risks money -- so none of these functions are
;; gated by `alpaca-broker-allow-orders', unlike `alpaca-broker-orders.el'.
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form (takes
;; CALLBACK as its last required argument) and a synchronous
;; `alpaca-broker-FOO-sync' form, same convention as the rest of this
;; package.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- by id --

;;;###autoload
(defun alpaca-broker-watchlists (callback)
  "Fetch every Alpaca watchlist (summary form) and call CALLBACK.
CALLBACK is called with the parsed JSON list of watchlist alists
\(Alpaca's raw `GET /v2/watchlists' response -- each without its
`assets' array; fetch a single watchlist for that)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/watchlists" nil nil callback))

(defun alpaca-broker-watchlists-sync ()
  "Fetch and return every Alpaca watchlist (summary form).
Synchronous form of `alpaca-broker-watchlists'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/watchlists"))

;;;###autoload
(defun alpaca-broker-create-watchlist (name callback &optional symbols)
  "Create an Alpaca watchlist named NAME and call CALLBACK.
SYMBOLS is an optional list of symbol strings to seed it with.
CALLBACK is called with the parsed JSON alist for the created
watchlist (including its `assets' array)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST" "/v2/watchlists" nil
   `(("name" . ,name) ,@(and symbols `(("symbols" . ,symbols))))
   callback))

(defun alpaca-broker-create-watchlist-sync (name &optional symbols)
  "Create and return an Alpaca watchlist named NAME.
Synchronous form of `alpaca-broker-create-watchlist'; see it for
SYMBOLS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST" "/v2/watchlists" nil
   `(("name" . ,name) ,@(and symbols `(("symbols" . ,symbols))))))

;;;###autoload
(defun alpaca-broker-watchlist (watchlist-id callback)
  "Fetch Alpaca watchlist WATCHLIST-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist (including its `assets'
array)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))
   nil nil callback))

(defun alpaca-broker-watchlist-sync (watchlist-id)
  "Fetch and return Alpaca watchlist WATCHLIST-ID.
Synchronous form of `alpaca-broker-watchlist'; see it for WATCHLIST-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))))

;;;###autoload
(defun alpaca-broker-update-watchlist (watchlist-id updates callback)
  "Update Alpaca watchlist WATCHLIST-ID with UPDATES and call CALLBACK.
UPDATES is an alist (`name', `symbols' -- `symbols' replaces the
watchlist's full asset list).  CALLBACK is called with the parsed JSON
alist for the updated watchlist."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "PUT"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))
   nil updates callback))

(defun alpaca-broker-update-watchlist-sync (watchlist-id updates)
  "Update and return Alpaca watchlist WATCHLIST-ID with UPDATES.
Synchronous form of `alpaca-broker-update-watchlist'; see it for
UPDATES."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "PUT"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))
   nil updates))

;;;###autoload
(defun alpaca-broker-add-watchlist-asset (watchlist-id symbol callback)
  "Add SYMBOL to Alpaca watchlist WATCHLIST-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist for the updated
watchlist."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))
   nil `(("symbol" . ,symbol)) callback))

(defun alpaca-broker-add-watchlist-asset-sync (watchlist-id symbol)
  "Add SYMBOL to Alpaca watchlist WATCHLIST-ID and return it updated.
Synchronous form of `alpaca-broker-add-watchlist-asset'; see it for
WATCHLIST-ID/SYMBOL."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))
   nil `(("symbol" . ,symbol))))

;;;###autoload
(defun alpaca-broker-remove-watchlist-asset (watchlist-id symbol callback)
  "Remove SYMBOL from Alpaca watchlist WATCHLIST-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist for the updated
watchlist."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/watchlists/%s/%s"
           (url-hexify-string watchlist-id) (url-hexify-string symbol))
   nil nil callback))

(defun alpaca-broker-remove-watchlist-asset-sync (watchlist-id symbol)
  "Remove SYMBOL from Alpaca watchlist WATCHLIST-ID and return it updated.
Synchronous form of `alpaca-broker-remove-watchlist-asset'; see it for
WATCHLIST-ID/SYMBOL."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/watchlists/%s/%s"
           (url-hexify-string watchlist-id) (url-hexify-string symbol))))

;;;###autoload
(defun alpaca-broker-delete-watchlist (watchlist-id callback)
  "Permanently delete Alpaca watchlist WATCHLIST-ID and call CALLBACK.
CALLBACK is called with nil on success (Alpaca returns 204 No
Content)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))
   nil nil callback))

(defun alpaca-broker-delete-watchlist-sync (watchlist-id)
  "Permanently delete Alpaca watchlist WATCHLIST-ID.
Synchronous form of `alpaca-broker-delete-watchlist'; see it for WATCHLIST-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/watchlists/%s" (url-hexify-string watchlist-id))))

;; -- by name --

;;;###autoload
(defun alpaca-broker-watchlist-by-name (name callback)
  "Fetch Alpaca watchlist named NAME and call CALLBACK.
CALLBACK is called with the parsed JSON alist (including its `assets'
array)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/watchlists:by_name"
   `(("name" . ,name)) nil callback))

(defun alpaca-broker-watchlist-by-name-sync (name)
  "Fetch and return Alpaca watchlist named NAME.
Synchronous form of `alpaca-broker-watchlist-by-name'; see it for NAME."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/watchlists:by_name"
   `(("name" . ,name))))

;;;###autoload
(defun alpaca-broker-update-watchlist-by-name (name updates callback)
  "Update the Alpaca watchlist named NAME with UPDATES and call CALLBACK.
UPDATES is an alist (`name' -- renames it, `symbols' -- replaces its
full asset list).  CALLBACK is called with the parsed JSON alist for
the updated watchlist."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "PUT" "/v2/watchlists:by_name"
   `(("name" . ,name)) updates callback))

(defun alpaca-broker-update-watchlist-by-name-sync (name updates)
  "Update and return the Alpaca watchlist named NAME with UPDATES.
Synchronous form of `alpaca-broker-update-watchlist-by-name'; see it
for UPDATES."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "PUT" "/v2/watchlists:by_name"
   `(("name" . ,name)) updates))

;;;###autoload
(defun alpaca-broker-add-watchlist-asset-by-name (name symbol callback)
  "Add SYMBOL to the Alpaca watchlist named NAME and call CALLBACK.
CALLBACK is called with the parsed JSON alist for the updated
watchlist."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST" "/v2/watchlists:by_name"
   `(("name" . ,name)) `(("symbol" . ,symbol)) callback))

(defun alpaca-broker-add-watchlist-asset-by-name-sync (name symbol)
  "Add SYMBOL to the Alpaca watchlist named NAME and return it updated.
Synchronous form of `alpaca-broker-add-watchlist-asset-by-name'; see
it for NAME/SYMBOL."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST" "/v2/watchlists:by_name"
   `(("name" . ,name)) `(("symbol" . ,symbol))))

;;;###autoload
(defun alpaca-broker-delete-watchlist-by-name (name callback)
  "Permanently delete the Alpaca watchlist named NAME and call CALLBACK.
CALLBACK is called with nil on success (Alpaca returns 204 No
Content).  There is no by-name equivalent of removing a single symbol
from a watchlist -- use `alpaca-broker-remove-watchlist-asset' (by id)
for that."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE" "/v2/watchlists:by_name"
   `(("name" . ,name)) nil callback))

(defun alpaca-broker-delete-watchlist-by-name-sync (name)
  "Permanently delete the Alpaca watchlist named NAME.
Synchronous form of `alpaca-broker-delete-watchlist-by-name'; see it for NAME."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE" "/v2/watchlists:by_name"
   `(("name" . ,name))))

(provide 'alpaca-broker-watchlists)
;;; alpaca-broker-watchlists.el ends here
