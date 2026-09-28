;;; alpaca-broker-trading-test.el --- Tests for alpaca-broker-trading.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-trading.el': account, account
;; configurations, account activities, portfolio history, assets,
;; option contracts, the deprecated v2 corporate-action announcements,
;; the market calendar, and the market clock.  Each test asserts the
;; HTTP method, path, query params, and (where applicable) request
;; body of one endpoint -- see
;; `alpaca-broker-test--capture-request' in
;; `alpaca-broker-test-helpers.el'.  Mocks at the
;; `url-retrieve-synchronously' boundary; never makes a real network
;; call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-trading)

(defconst alpaca-broker-trading-test--paper "https://paper-api.alpaca.markets")

;; -- account --

(ert-deftest alpaca-broker-trading-test-account-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-account-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper "/v2/account"))))))

;; -- account configurations --

(ert-deftest alpaca-broker-trading-test-account-configurations-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-account-configurations-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/account/configurations"))))))

(ert-deftest alpaca-broker-trading-test-update-account-configurations-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-update-account-configurations-sync
                  '(("suspend_trade" . t))))))
      (should (equal (plist-get req :method) "PATCH"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/account/configurations")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((suspend_trade . t)))))))

;; -- account activities --

(ert-deftest alpaca-broker-trading-test-account-activities-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-account-activities-sync
                  '(("activity_types" . "FILL") ("direction" . "asc"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/account/activities"
                              "?activity_types=FILL&direction=asc"))))))

(ert-deftest alpaca-broker-trading-test-account-activities-all-sync-paginates-by-id ()
  "Alpaca paginates account activities via `page_token' set to the
previous page's last activity `id', not `next_page_token' -- assert
the loop actually walks that chain and stops on a short final page."
  (let ((alpaca-broker-paper t) (page 0))
    (cl-letf (((symbol-function 'alpaca-broker-account-activities-sync)
               (lambda (params)
                 (setq page (1+ page))
                 (let ((token (alist-get "page_token" params nil nil #'equal)))
                   (cond
                    ((null token)
                     (list '((id . "a1") (activity_type . "FILL"))
                           '((id . "a2") (activity_type . "FILL"))))
                    ((equal token "a2")
                     (list '((id . "a3") (activity_type . "FILL"))))
                    (t (ert-fail "unexpected page_token")))))))
      (let ((result (alpaca-broker-account-activities-all-sync
                     '(("page_size" . "2")))))
        (should (equal (mapcar (lambda (a) (alist-get 'id a)) result)
                        '("a1" "a2" "a3")))
        (should (= page 2))))))

(ert-deftest alpaca-broker-trading-test-account-activities-by-type-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-account-activities-by-type-sync "DIV"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/account/activities/DIV"))))))

;; -- portfolio history --

(ert-deftest alpaca-broker-trading-test-portfolio-history-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-portfolio-history-sync
                  '(("period" . "1M") ("timeframe" . "1D"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/account/portfolio/history"
                              "?period=1M&timeframe=1D"))))))

;; -- assets --

(ert-deftest alpaca-broker-trading-test-assets-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-assets-sync '(("status" . "active"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/assets?status=active"))))))

(ert-deftest alpaca-broker-trading-test-asset-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-asset-sync "AAPL"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/assets/AAPL"))))))

;; -- option contracts --

(ert-deftest alpaca-broker-trading-test-option-contracts-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-option-contracts-sync
                  '(("underlying_symbols" . "AAPL"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/options/contracts?underlying_symbols=AAPL"))))))

(ert-deftest alpaca-broker-trading-test-option-contracts-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-option-contracts-sync)
               (lambda (params)
                 (setq page (1+ page))
                 (let ((token (alist-get "page_token" params nil nil #'equal)))
                   (if (null token)
                       '((next_page_token . "tok-2")
                         (option_contracts . (((symbol . "AAPL240101C00100000")))))
                     '((next_page_token . nil)
                       (option_contracts . (((symbol . "AAPL240101P00100000")))))))))
              )
      (let ((result (alpaca-broker-option-contracts-all-sync)))
        (should (= (length result) 2))
        (should (= page 2))))))

(ert-deftest alpaca-broker-trading-test-option-contract-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-option-contract-sync "AAPL240101C00100000"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/options/contracts/AAPL240101C00100000"))))))

;; -- corporate action announcements (deprecated v2) --

(ert-deftest alpaca-broker-trading-test-corporate-action-announcements-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-corporate-action-announcements-sync
                  "Dividend" "2024-01-01" "2024-02-01"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/corporate_actions/announcements"
                              "?ca_types=Dividend&since=2024-01-01"
                              "&until=2024-02-01"))))))

(ert-deftest alpaca-broker-trading-test-corporate-action-announcement-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-corporate-action-announcement-sync "ca-1"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/corporate_actions/announcements/ca-1"))))))

;; -- calendar --

(ert-deftest alpaca-broker-trading-test-calendar-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-calendar-sync '(("start" . "2024-01-01"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper
                              "/v2/calendar?start=2024-01-01"))))))

;; -- clock --

(ert-deftest alpaca-broker-trading-test-clock-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-clock-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-trading-test--paper "/v2/clock"))))))

(provide 'alpaca-broker-trading-test)
;;; alpaca-broker-trading-test.el ends here
