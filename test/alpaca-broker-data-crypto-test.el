;;; alpaca-broker-data-crypto-test.el --- Tests for alpaca-broker-data-crypto.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-data-crypto.el': the three
;; single-symbol unwrap-convenience fetchers plus the `-multi' raw
;; fetchers for bars, trades, quotes, latest order books, and
;; snapshots.  Each test asserts the HTTP method, path, and query
;; params of one endpoint.  Mocks at the `url-retrieve-synchronously'
;; boundary; never makes a real network call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-data-crypto)

(defconst alpaca-broker-data-crypto-test--root "https://data.alpaca.markets")

;; -- crypto-unwrap (pure function) --

(ert-deftest alpaca-broker-data-crypto-test-crypto-unwrap-extracts-entry ()
  (should (equal (alpaca-broker--crypto-unwrap
                   `((quotes . ((,(intern "BTC/USD") . ((bp . 50000) (ap . 50010))))))
                   'quotes "BTC/USD")
                  '((bp . 50000) (ap . 50010)))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-unwrap-nil-when-absent ()
  (should (null (alpaca-broker--crypto-unwrap '((quotes . nil)) 'quotes "BTC/USD"))))

;; -- historical bars --

(ert-deftest alpaca-broker-data-crypto-test-crypto-bars-sync-default-loc ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-bars-sync "BTC/USD" "1Day"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/bars"
                            "?symbols=BTC%2FUSD&timeframe=1Day")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-bars-sync-custom-loc ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-bars-sync
                "BTC/USD" "1Day" nil nil nil "us-1"))))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us-1/bars"
                            "?symbols=BTC%2FUSD&timeframe=1Day")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-bars-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-bars-multi-sync
                '("BTC/USD" "ETH/USD") "1Day"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/bars"
                            "?symbols=BTC%2FUSD%2CETH%2FUSD&timeframe=1Day")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-bars-multi-all-sync-paginates ()
  (let ((page 0) (btc-usd (intern "BTC/USD")))
    (cl-letf (((symbol-function 'alpaca-broker-crypto-bars-multi-sync)
               (lambda (_symbols _tf params _loc)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     (list (cons 'next_page_token "tok-2")
                           (list 'bars (cons btc-usd '(1))))
                   (list (cons 'next_page_token nil)
                         (list 'bars (cons btc-usd '(2))))))))
      (let ((result (alpaca-broker-crypto-bars-multi-all-sync
                     '("BTC/USD") "1Day")))
        (should (equal (alist-get btc-usd result) '(1 2)))
        (should (= page 2))))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-latest-bars-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-latest-bars-multi-sync '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/latest/bars?symbols=BTC%2FUSD")))))

;; -- historical trades --

(ert-deftest alpaca-broker-data-crypto-test-crypto-trades-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-trades-multi-sync '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/trades?symbols=BTC%2FUSD")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-latest-trade-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-latest-trade-sync "BTC/USD"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/latest/trades?symbols=BTC%2FUSD")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-latest-trades-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-latest-trades-multi-sync '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/latest/trades?symbols=BTC%2FUSD")))))

;; -- historical quotes --

(ert-deftest alpaca-broker-data-crypto-test-crypto-latest-quote-sync ()
  (let ((req (alpaca-broker-test--capture-request-with-response
                 "{\"quotes\":{\"BTC/USD\":{\"bp\":50000,\"ap\":50010}}}"
               (alpaca-broker-crypto-latest-quote-sync "BTC/USD"))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/latest/quotes?symbols=BTC%2FUSD")))
    (should (equal (alist-get 'bp (plist-get req :result)) 50000))
    (should (equal (alist-get 'ap (plist-get req :result)) 50010))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-quotes-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-quotes-multi-sync '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/quotes?symbols=BTC%2FUSD")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-latest-quotes-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-latest-quotes-multi-sync '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/latest/quotes?symbols=BTC%2FUSD")))))

;; -- order books and snapshots --

(ert-deftest alpaca-broker-data-crypto-test-crypto-latest-orderbooks-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-latest-orderbooks-multi-sync
                '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/latest/orderbooks"
                            "?symbols=BTC%2FUSD")))))

(ert-deftest alpaca-broker-data-crypto-test-crypto-snapshots-multi-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-crypto-snapshots-multi-sync '("BTC/USD")))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-crypto-test--root
                            "/v1beta3/crypto/us/snapshots?symbols=BTC%2FUSD")))))

(provide 'alpaca-broker-data-crypto-test)
;;; alpaca-broker-data-crypto-test.el ends here
