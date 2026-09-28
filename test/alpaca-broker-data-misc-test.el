;;; alpaca-broker-data-misc-test.el --- Tests for alpaca-broker-data-misc.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-data-misc.el': forex rates,
;; fixed-income latest prices/quotes, the stock/crypto screener, symbol
;; logos, and the market-data flavor of corporate actions.  Each test
;; asserts the HTTP method, path, and query params of one endpoint.
;; Mocks at the `url-retrieve-synchronously' boundary; never makes a
;; real network call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-data-misc)

(defconst alpaca-broker-data-misc-test--root "https://data.alpaca.markets")

;; -- forex --

(ert-deftest alpaca-broker-data-misc-test-forex-rates-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-forex-rates-sync '("EUR/USD" "GBP/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1beta1/forex/rates"
                            "?currency_pairs=EUR%2FUSD%2CGBP%2FUSD")))))

(ert-deftest alpaca-broker-data-misc-test-forex-rates-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-forex-rates-sync)
               (lambda (_pairs params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2") (rates . ((eurusd . (1)))))
                   '((next_page_token . nil) (rates . ((eurusd . (2)))))))))
      (let ((result (alpaca-broker-forex-rates-all-sync '("EUR/USD"))))
        (should (equal (alist-get 'eurusd result) '(1 2)))
        (should (= page 2))))))

(ert-deftest alpaca-broker-data-misc-test-forex-latest-rates-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-forex-latest-rates-sync "EUR/USD"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1beta1/forex/latest/rates?currency_pairs=EUR%2FUSD")))))

;; -- fixed income --

(ert-deftest alpaca-broker-data-misc-test-fixed-income-latest-prices-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-fixed-income-latest-prices-sync "US912810TW82"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1beta1/fixed_income/latest/prices"
                            "?isins=US912810TW82")))))

(ert-deftest alpaca-broker-data-misc-test-fixed-income-latest-quotes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-fixed-income-latest-quotes-sync
                "US912810TW82" '(("trade_size" . "10"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1beta1/fixed_income/latest/quotes"
                            "?isins=US912810TW82&trade_size=10")))))

;; -- screener --

(ert-deftest alpaca-broker-data-misc-test-screener-most-actives-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-screener-most-actives-sync
                '(("by" . "volume") ("top" . "5"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1beta1/screener/stocks/most-actives"
                            "?by=volume&top=5")))))

(ert-deftest alpaca-broker-data-misc-test-screener-movers-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-screener-movers-sync "stocks" '(("top" . "5"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1beta1/screener/stocks/movers?top=5")))))

;; -- logos --

(ert-deftest alpaca-broker-data-misc-test-logo-sync-returns-raw-bytes ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-url)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (url &rest _)
                     (setq seen-url url)
                     (alpaca-broker-test--fake-response-buffer
                      200 "FAKE-PNG-BYTES"))))
          (should (equal (alpaca-broker-logo-sync "AAPL") "FAKE-PNG-BYTES"))
          (should (equal seen-url
                          (concat alpaca-broker-data-misc-test--root
                                  "/v1beta1/logos/AAPL")))))))

(ert-deftest alpaca-broker-data-misc-test-logo-sync-passes-placeholder-param ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-url)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (url &rest _)
                     (setq seen-url url)
                     (alpaca-broker-test--fake-response-buffer 200 ""))))
          (alpaca-broker-logo-sync "AAPL" :false)
          (should (equal seen-url
                          (concat alpaca-broker-data-misc-test--root
                                  "/v1beta1/logos/AAPL?placeholder=false")))))))

;; -- corporate actions (market-data flavor) --

(ert-deftest alpaca-broker-data-misc-test-corporate-actions-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-corporate-actions-sync
                '(("symbols" . "AAPL") ("types" . "cash_dividend"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-misc-test--root
                            "/v1/corporate-actions"
                            "?symbols=AAPL&types=cash_dividend")))))

(ert-deftest alpaca-broker-data-misc-test-corporate-actions-all-sync-merges-typed-collections ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-corporate-actions-sync)
               (lambda (params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2")
                       (corporate_actions
                        . ((cash_dividends . (d1))
                           (forward_splits . (s1)))))
                   '((next_page_token . nil)
                     (corporate_actions
                      . ((cash_dividends . (d2)))))))))
      (let ((result (alpaca-broker-corporate-actions-all-sync)))
        (should (equal (alist-get 'cash_dividends result) '(d1 d2)))
        (should (equal (alist-get 'forward_splits result) '(s1)))
        (should (= page 2))))))

(provide 'alpaca-broker-data-misc-test)
;;; alpaca-broker-data-misc-test.el ends here
