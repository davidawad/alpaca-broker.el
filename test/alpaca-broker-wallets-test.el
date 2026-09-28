;;; alpaca-broker-wallets-test.el --- Tests for alpaca-broker-wallets.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-wallets.el': crypto funding
;; wallets, fee estimates, transfers, VASP search, and whitelisted
;; withdrawal addresses.  Each test asserts the HTTP method, path,
;; query params, and (where applicable) request body of one endpoint.
;; The transfer/whitelist-mutating functions are additionally asserted
;; to signal a `user-error' when `alpaca-broker-allow-orders' is nil.
;; Mocks at the `url-retrieve-synchronously' boundary; never makes a
;; real network call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-wallets)

(defconst alpaca-broker-wallets-test--paper "https://paper-api.alpaca.markets")

;; -- read --

(ert-deftest alpaca-broker-wallets-test-wallets-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-wallets-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper "/v2/wallets"))))))

(ert-deftest alpaca-broker-wallets-test-wallet-fee-estimate-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-wallet-fee-estimate-sync
                  '(("asset" . "BTC") ("amount" . "0.01"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/fees/estimate"
                              "?asset=BTC&amount=0.01"))))))

(ert-deftest alpaca-broker-wallets-test-wallet-transfers-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-wallet-transfers-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/transfers"))))))

(ert-deftest alpaca-broker-wallets-test-wallet-transfer-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-wallet-transfer-sync "transfer-1"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/transfers/transfer-1"))))))

(ert-deftest alpaca-broker-wallets-test-wallet-vasps-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-wallet-vasps-sync '(("q" . "Kraken"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/travel-rule/vasps?q=Kraken"))))))

(ert-deftest alpaca-broker-wallets-test-wallet-whitelist-addresses-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-wallet-whitelist-addresses-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/whitelists"))))))

;; -- mutate (gated) --

(ert-deftest alpaca-broker-wallets-test-create-wallet-transfer-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error
     (alpaca-broker-create-wallet-transfer-sync '(("asset" . "BTC")))
     :type 'user-error)))

(ert-deftest alpaca-broker-wallets-test-create-wallet-transfer-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-create-wallet-transfer-sync
                  '(("asset" . "BTC") ("amount" . "0.01")
                    ("address" . "bc1qexample"))))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/transfers")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((asset . "BTC") (amount . "0.01")
                        (address . "bc1qexample")))))))

(ert-deftest alpaca-broker-wallets-test-create-wallet-whitelist-address-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error
     (alpaca-broker-create-wallet-whitelist-address-sync
      '(("address" . "bc1qexample")))
     :type 'user-error)))

(ert-deftest alpaca-broker-wallets-test-create-wallet-whitelist-address-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-create-wallet-whitelist-address-sync
                  '(("address" . "bc1qexample") ("asset" . "BTC")
                    ("chain" . "BTC"))))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/whitelists")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((address . "bc1qexample") (asset . "BTC")
                        (chain . "BTC")))))))

(ert-deftest alpaca-broker-wallets-test-delete-wallet-whitelist-address-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error
     (alpaca-broker-delete-wallet-whitelist-address-sync "wl-addr-1")
     :type 'user-error)))

(ert-deftest alpaca-broker-wallets-test-delete-wallet-whitelist-address-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-delete-wallet-whitelist-address-sync
                  "wl-addr-1"))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/whitelists/wl-addr-1"))))))

(ert-deftest alpaca-broker-wallets-test-update-wallet-whitelist-travel-rule-info-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error
     (alpaca-broker-update-wallet-whitelist-travel-rule-info-sync
      "wl-addr-1" '(("beneficiary_given_name" . "Jane")))
     :type 'user-error)))

(ert-deftest alpaca-broker-wallets-test-update-wallet-whitelist-travel-rule-info-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-update-wallet-whitelist-travel-rule-info-sync
                  "wl-addr-1" '(("beneficiary_given_name" . "Jane"))))))
      (should (equal (plist-get req :method) "PATCH"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-wallets-test--paper
                              "/v2/wallets/whitelists/wl-addr-1/travel-rule-info")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((travel_rule_info
                         . ((beneficiary_given_name . "Jane")))))))))

(provide 'alpaca-broker-wallets-test)
;;; alpaca-broker-wallets-test.el ends here
