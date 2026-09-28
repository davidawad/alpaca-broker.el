;;; alpaca-broker-data-options-test.el --- Tests for alpaca-broker-data-options.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-data-options.el': historical
;; bars/trades, latest trades/quotes, snapshots, the option chain, and
;; the condition-code/exchange-code metadata endpoints.  Each test
;; asserts the HTTP method, path, and query params of one endpoint.
;; Mocks at the `url-retrieve-synchronously' boundary; never makes a
;; real network call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-data-options)

(defconst alpaca-broker-data-options-test--root "https://data.alpaca.markets")

(ert-deftest alpaca-broker-data-options-test-options-bars-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-bars-sync
                "AAPL240101C00100000" "1Day"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/bars"
                            "?symbols=AAPL240101C00100000&timeframe=1Day")))))

(ert-deftest alpaca-broker-data-options-test-options-bars-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-options-bars-sync)
               (lambda (_symbols _tf params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2") (bars . ((sym . (1)))))
                   '((next_page_token . nil) (bars . ((sym . (2)))))))))
      (let ((result (alpaca-broker-options-bars-all-sync "sym" "1Day")))
        (should (equal (alist-get 'sym result) '(1 2)))
        (should (= page 2))))))

(ert-deftest alpaca-broker-data-options-test-options-trades-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-trades-sync "AAPL240101C00100000"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/trades"
                            "?symbols=AAPL240101C00100000")))))

(ert-deftest alpaca-broker-data-options-test-options-latest-trades-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-latest-trades-sync
                "AAPL240101C00100000"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/trades/latest"
                            "?symbols=AAPL240101C00100000")))))

(ert-deftest alpaca-broker-data-options-test-options-latest-quotes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-latest-quotes-sync
                "AAPL240101C00100000"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/quotes/latest"
                            "?symbols=AAPL240101C00100000")))))

(ert-deftest alpaca-broker-data-options-test-options-snapshots-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-snapshots-sync
                "AAPL240101C00100000"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/snapshots"
                            "?symbols=AAPL240101C00100000")))))

(ert-deftest alpaca-broker-data-options-test-options-chain-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-chain-sync
                "AAPL" '(("type" . "call"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/snapshots/AAPL?type=call")))))

(ert-deftest alpaca-broker-data-options-test-options-chain-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-options-chain-sync)
               (lambda (_underlying params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2")
                       (snapshots . ((sym1 . a))))
                   '((next_page_token . nil) (snapshots . ((sym2 . b))))))))
      (let ((result (alpaca-broker-options-chain-all-sync "AAPL")))
        (should (equal (alist-get 'sym1 result) 'a))
        (should (equal (alist-get 'sym2 result) 'b))
        (should (= page 2))))))

(ert-deftest alpaca-broker-data-options-test-condition-codes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-condition-codes-sync "quote"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/meta/conditions/quote")))))

(ert-deftest alpaca-broker-data-options-test-exchange-codes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-options-exchange-codes-sync))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-options-test--root
                            "/v1beta1/options/meta/exchanges")))))

(provide 'alpaca-broker-data-options-test)
;;; alpaca-broker-data-options-test.el ends here
