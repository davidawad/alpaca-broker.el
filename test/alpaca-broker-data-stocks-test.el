;;; alpaca-broker-data-stocks-test.el --- Tests for alpaca-broker-data-stocks.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-data-stocks.el': historical and
;; latest bars/trades/quotes (single- and multi-symbol), snapshots,
;; auctions, and the condition-code/exchange-code metadata endpoints.
;; Each test asserts the HTTP method, path, and query params of one
;; endpoint.  Mocks at the `url-retrieve-synchronously' boundary; never
;; makes a real network call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-data-stocks)

(defconst alpaca-broker-data-stocks-test--root "https://data.alpaca.markets")

;; -- historical bars --

(ert-deftest alpaca-broker-data-stocks-test-bars-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-bars-sync "AAPL" "1Day" "2024-01-01" "2024-02-01" 10))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/bars"
                            "?timeframe=1Day&start=2024-01-01"
                            "&end=2024-02-01&limit=10")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-bars-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-bars-sync
                '("AAPL" "MSFT") "1Day" '(("feed" . "iex"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/bars"
                            "?symbols=AAPL%2CMSFT&timeframe=1Day&feed=iex")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-bars-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-stocks-bars-sync)
               (lambda (_symbols _tf params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2")
                       (bars . ((AAPL . (1)))))
                   '((next_page_token . nil) (bars . ((AAPL . (2)))))))))
      (let ((result (alpaca-broker-stocks-bars-all-sync '("AAPL") "1Day")))
        (should (equal (alist-get 'AAPL result) '(1 2)))
        (should (= page 2))))))

(ert-deftest alpaca-broker-data-stocks-test-latest-bar-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-latest-bar-sync "AAPL"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/bars/latest")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-latest-bars-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-latest-bars-sync '("AAPL" "MSFT")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/bars/latest?symbols=AAPL%2CMSFT")))))

;; -- historical trades --

(ert-deftest alpaca-broker-data-stocks-test-trades-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-trades-sync "AAPL" '(("limit" . "5"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/trades?limit=5")))))

(ert-deftest alpaca-broker-data-stocks-test-trades-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-trades-sync)
               (lambda (_symbol params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2") (trades . (1)))
                   '((next_page_token . nil) (trades . (2)))))))
      (should (equal (alpaca-broker-trades-all-sync "AAPL") '(1 2)))
      (should (= page 2)))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-trades-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-trades-sync '("AAPL" "MSFT")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/trades?symbols=AAPL%2CMSFT")))))

(ert-deftest alpaca-broker-data-stocks-test-latest-trade-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-latest-trade-sync "AAPL"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/trades/latest")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-latest-trades-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-latest-trades-sync '("AAPL")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/trades/latest?symbols=AAPL")))))

;; -- historical quotes --

(ert-deftest alpaca-broker-data-stocks-test-latest-quote-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-latest-quote-sync "AAPL"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/quotes/latest")))))

(ert-deftest alpaca-broker-data-stocks-test-quotes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-quotes-sync "AAPL"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/quotes")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-quotes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-quotes-sync '("AAPL" "MSFT")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/quotes?symbols=AAPL%2CMSFT")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-latest-quotes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-latest-quotes-sync '("AAPL")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/quotes/latest?symbols=AAPL")))))

;; -- snapshots --

(ert-deftest alpaca-broker-data-stocks-test-snapshot-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-snapshot-sync "AAPL"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/snapshot")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-snapshots-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-snapshots-sync '("AAPL" "MSFT")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/snapshots?symbols=AAPL%2CMSFT")))))

;; -- auctions --

(ert-deftest alpaca-broker-data-stocks-test-auctions-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-auctions-sync "AAPL"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/AAPL/auctions")))))

(ert-deftest alpaca-broker-data-stocks-test-stocks-auctions-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-auctions-sync '("AAPL")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/auctions?symbols=AAPL")))))

;; -- meta --

(ert-deftest alpaca-broker-data-stocks-test-condition-codes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-condition-codes-sync "trade" "A"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/meta/conditions/trade?tape=A")))))

(ert-deftest alpaca-broker-data-stocks-test-exchange-codes-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-stocks-exchange-codes-sync))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-stocks-test--root
                            "/v2/stocks/meta/exchanges")))))

;; -- demo command --

(ert-deftest alpaca-broker-data-stocks-test-show-quote-messages-bid-ask ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (messages)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _)
                     (alpaca-broker-test--fake-response-buffer
                      200
                      "{\"symbol\":\"AAPL\",\"quote\":{\"bp\":150.1,\"bs\":2,\"ap\":150.3,\"as\":4}}")))
                  ((symbol-function 'message)
                   (lambda (fmt &rest args)
                     (push (apply #'format fmt args) messages))))
          (alpaca-broker-show-quote "AAPL")
          (should (equal (car messages) "AAPL: bid 150.1 x2 / ask 150.3 x4"))))))

(provide 'alpaca-broker-data-stocks-test)
;;; alpaca-broker-data-stocks-test.el ends here
