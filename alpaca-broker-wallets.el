;;; alpaca-broker-wallets.el --- Crypto funding wallet endpoints for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Maintainer: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca's Crypto Funding endpoints (https://api.alpaca.markets or
;; https://paper-api.alpaca.markets, `/v2/wallets/...') -- self-custody
;; on-chain crypto deposit/withdrawal for individual brokerage accounts.
;; This is genuinely part of the Trading API (tagged "Crypto Funding" in
;; Alpaca's own OpenAPI spec), distinct from the out-of-scope Broker
;; API's journals/ACATS.  Alpaca's separate Tokenization endpoints
;; (`/v2/tokenization/...') and the Locates API (`/v1/locates/...') are
;; NOT implemented here -- neither was requested in scope.
;;
;; Every function that REQUESTS a withdrawal, REQUESTS a whitelisted
;; address, DELETES a whitelisted address, or UPDATES a whitelisted
;; address's travel-rule info calls
;; `alpaca-broker--require-order-permission' first, same gate as
;; `alpaca-broker-orders.el' -- an on-chain crypto transfer is at least
;; as irreversible as a trade, so it gets the same
;; `alpaca-broker-allow-orders' protection even though Alpaca's own docs
;; don't call it an \"order.\"
;;
;; Every fetcher has an asynchronous `alpaca-broker-FOO' form and a
;; synchronous `alpaca-broker-FOO-sync' form, same convention as the
;; rest of this package.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;; -- read --

;;;###autoload
(defun alpaca-broker-wallets (callback &optional params)
  "Fetch (or lazily create) Alpaca crypto wallets and call CALLBACK.
PARAMS is an optional alist for Alpaca's own `GET /v2/wallets' query
parameters.  CALLBACK is called with the parsed JSON response (an
array when listing, a single wallet alist when PARAMS scopes to one
asset -- Alpaca's own documented but underspecified behavior)."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets" params nil
   callback))

(defun alpaca-broker-wallets-sync (&optional params)
  "Fetch and return Alpaca crypto wallets.
Synchronous form of `alpaca-broker-wallets'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets" params))

;;;###autoload
(defun alpaca-broker-wallet-fee-estimate (callback &optional params)
  "Estimate the on-chain fee for a proposed withdrawal and call CALLBACK.
PARAMS is an optional alist (`asset', `from_address', `to_address',
`amount').  CALLBACK is called with the parsed JSON alist (`fee',
`network_fee')."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/fees/estimate"
   params nil callback))

(defun alpaca-broker-wallet-fee-estimate-sync (&optional params)
  "Fetch and return the estimated on-chain fee for a proposed withdrawal.
Synchronous form of `alpaca-broker-wallet-fee-estimate'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/fees/estimate"
   params))

;;;###autoload
(defun alpaca-broker-wallet-transfers (callback)
  "Fetch every Alpaca crypto wallet transfer and call CALLBACK.
CALLBACK is called with the parsed JSON list of transfer alists."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/transfers" nil nil
   callback))

(defun alpaca-broker-wallet-transfers-sync ()
  "Fetch and return every Alpaca crypto wallet transfer.
Synchronous form of `alpaca-broker-wallet-transfers'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/transfers"))

;;;###autoload
(defun alpaca-broker-wallet-transfer (transfer-id callback)
  "Fetch Alpaca crypto wallet transfer TRANSFER-ID and call CALLBACK.
CALLBACK is called with the parsed JSON alist."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/wallets/transfers/%s" (url-hexify-string transfer-id))
   nil nil callback))

(defun alpaca-broker-wallet-transfer-sync (transfer-id)
  "Fetch and return Alpaca crypto wallet transfer TRANSFER-ID.
Synchronous form of `alpaca-broker-wallet-transfer'; see it for TRANSFER-ID."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET"
   (format "/v2/wallets/transfers/%s" (url-hexify-string transfer-id))))

;;;###autoload
(defun alpaca-broker-wallet-vasps (callback &optional params)
  "Search Notabene's VASP directory (for travel-rule lookups).
PARAMS is an optional alist (`q', `emailDomain', `chainalysisName',
`fields', `page', `per_page', `order', `includeSubsidiaryVASPs').
CALLBACK is called with the parsed JSON alist (`page', `pages',
`total', `vasps')."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/travel-rule/vasps"
   params nil callback))

(defun alpaca-broker-wallet-vasps-sync (&optional params)
  "Search and return matches from Notabene's VASP directory.
Synchronous form of `alpaca-broker-wallet-vasps'; see it for PARAMS."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/travel-rule/vasps"
   params))

;;;###autoload
(defun alpaca-broker-wallet-whitelist-addresses (callback)
  "Fetch every whitelisted Alpaca crypto withdrawal address and call CALLBACK.
CALLBACK is called with the parsed JSON list of whitelisted-address
alists."
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/whitelists" nil nil
   callback))

(defun alpaca-broker-wallet-whitelist-addresses-sync ()
  "Fetch and return every whitelisted Alpaca crypto withdrawal address.
Synchronous form of `alpaca-broker-wallet-whitelist-addresses'."
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "GET" "/v2/wallets/whitelists"))

;; -- mutate (gated) --

;;;###autoload
(defun alpaca-broker-create-wallet-transfer (transfer callback)
  "Request an Alpaca crypto wallet withdrawal and call CALLBACK.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
TRANSFER is an alist of Alpaca's own `POST /v2/wallets/transfers'
request-body fields (`address', `amount', `asset', `chain').  The
destination address must already be pre-whitelisted (at least 24 hours
in advance) or Alpaca rejects the transfer.  CALLBACK is called with
the parsed JSON alist for the created transfer."
  (alpaca-broker--require-order-permission 'alpaca-broker-create-wallet-transfer)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST" "/v2/wallets/transfers" nil
   transfer callback))

(defun alpaca-broker-create-wallet-transfer-sync (transfer)
  "Request an Alpaca crypto wallet withdrawal and return the transfer.
Synchronous form of `alpaca-broker-create-wallet-transfer'; see it for
TRANSFER and the `alpaca-broker-allow-orders' gate."
  (alpaca-broker--require-order-permission
   'alpaca-broker-create-wallet-transfer-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST" "/v2/wallets/transfers" nil
   transfer))

;;;###autoload
(defun alpaca-broker-create-wallet-whitelist-address (request callback)
  "Request a new whitelisted Alpaca crypto withdrawal address.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
REQUEST is an alist of Alpaca's own `POST /v2/wallets/whitelists'
request-body fields (`address', `asset', `chain', `travel_rule_info').
CALLBACK is called with the parsed JSON alist for the requested
address."
  (alpaca-broker--require-order-permission
   'alpaca-broker-create-wallet-whitelist-address)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "POST" "/v2/wallets/whitelists" nil
   request callback))

(defun alpaca-broker-create-wallet-whitelist-address-sync (request)
  "Request a new whitelisted Alpaca crypto withdrawal address.
Synchronous form of `alpaca-broker-create-wallet-whitelist-address'; see
it for REQUEST and the `alpaca-broker-allow-orders' gate."
  (alpaca-broker--require-order-permission
   'alpaca-broker-create-wallet-whitelist-address-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "POST" "/v2/wallets/whitelists" nil
   request))

;;;###autoload
(defun alpaca-broker-delete-wallet-whitelist-address (whitelisted-address-id callback)
  "Delete whitelisted Alpaca crypto withdrawal address WHITELISTED-ADDRESS-ID.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
CALLBACK is called with nil on success."
  (alpaca-broker--require-order-permission
   'alpaca-broker-delete-wallet-whitelist-address)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/wallets/whitelists/%s"
           (url-hexify-string whitelisted-address-id))
   nil nil callback))

(defun alpaca-broker-delete-wallet-whitelist-address-sync (whitelisted-address-id)
  "Delete whitelisted Alpaca crypto withdrawal address WHITELISTED-ADDRESS-ID.
Synchronous form of `alpaca-broker-delete-wallet-whitelist-address'.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil."
  (alpaca-broker--require-order-permission
   'alpaca-broker-delete-wallet-whitelist-address-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "DELETE"
   (format "/v2/wallets/whitelists/%s"
           (url-hexify-string whitelisted-address-id))))

;;;###autoload
(defun alpaca-broker-update-wallet-whitelist-travel-rule-info
    (whitelisted-address-id travel-rule-info callback)
  "Update travel-rule info for whitelisted address WHITELISTED-ADDRESS-ID.
Signals a `user-error' unless `alpaca-broker-allow-orders' is non-nil.
TRAVEL-RULE-INFO is an alist of Alpaca's own `PATCH
/v2/wallets/whitelists/WHITELISTED-ADDRESS-ID/travel-rule-info'
`travel_rule_info' request-body fields.  CALLBACK is called with the
parsed JSON alist for the updated address."
  (alpaca-broker--require-order-permission
   'alpaca-broker-update-wallet-whitelist-travel-rule-info)
  (alpaca-broker--request-async
   (alpaca-broker--trading-api-root) "PATCH"
   (format "/v2/wallets/whitelists/%s/travel-rule-info"
           (url-hexify-string whitelisted-address-id))
   nil `(("travel_rule_info" . ,travel-rule-info)) callback))

(defun alpaca-broker-update-wallet-whitelist-travel-rule-info-sync
    (whitelisted-address-id travel-rule-info)
  "Update travel-rule info for whitelisted address WHITELISTED-ADDRESS-ID.
Synchronous form of
`alpaca-broker-update-wallet-whitelist-travel-rule-info'; see it for
TRAVEL-RULE-INFO and the `alpaca-broker-allow-orders' gate."
  (alpaca-broker--require-order-permission
   'alpaca-broker-update-wallet-whitelist-travel-rule-info-sync)
  (alpaca-broker--request-sync
   (alpaca-broker--trading-api-root) "PATCH"
   (format "/v2/wallets/whitelists/%s/travel-rule-info"
           (url-hexify-string whitelisted-address-id))
   nil `(("travel_rule_info" . ,travel-rule-info))))

(provide 'alpaca-broker-wallets)
;;; alpaca-broker-wallets.el ends here
