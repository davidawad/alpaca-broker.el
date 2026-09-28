;;; alpaca-broker-watchlists-test.el --- Tests for alpaca-broker-watchlists.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-watchlists.el': full CRUD, both
;; by id and by name.  Each test asserts the HTTP method, path, query
;; params, and (where applicable) request body of one endpoint.  Mocks
;; at the `url-retrieve-synchronously' boundary; never makes a real
;; network call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-watchlists)

(defconst alpaca-broker-watchlists-test--paper "https://paper-api.alpaca.markets")

;; -- by id --

(ert-deftest alpaca-broker-watchlists-test-watchlists-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-watchlists-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists"))))))

(ert-deftest alpaca-broker-watchlists-test-create-watchlist-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-create-watchlist-sync
                  "Core" '("AAPL" "MSFT")))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((name . "Core") (symbols . ("AAPL" "MSFT"))))))))

(ert-deftest alpaca-broker-watchlists-test-watchlist-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-watchlist-sync "wl-1"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists/wl-1"))))))

(ert-deftest alpaca-broker-watchlists-test-update-watchlist-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-update-watchlist-sync
                  "wl-1" '(("name" . "Renamed"))))))
      (should (equal (plist-get req :method) "PUT"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists/wl-1")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((name . "Renamed")))))))

(ert-deftest alpaca-broker-watchlists-test-add-watchlist-asset-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-add-watchlist-asset-sync "wl-1" "AAPL"))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists/wl-1")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((symbol . "AAPL")))))))

(ert-deftest alpaca-broker-watchlists-test-remove-watchlist-asset-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-remove-watchlist-asset-sync "wl-1" "AAPL"))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists/wl-1/AAPL"))))))

(ert-deftest alpaca-broker-watchlists-test-delete-watchlist-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-delete-watchlist-sync "wl-1"))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists/wl-1"))))))

;; -- by name --

(ert-deftest alpaca-broker-watchlists-test-watchlist-by-name-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-watchlist-by-name-sync "Core"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists:by_name?name=Core"))))))

(ert-deftest alpaca-broker-watchlists-test-update-watchlist-by-name-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-update-watchlist-by-name-sync
                  "Core" '(("symbols" . ("AAPL")))))))
      (should (equal (plist-get req :method) "PUT"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists:by_name?name=Core")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((symbols . ("AAPL"))))))))

(ert-deftest alpaca-broker-watchlists-test-add-watchlist-asset-by-name-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-add-watchlist-asset-by-name-sync
                  "Core" "AAPL"))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists:by_name?name=Core")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((symbol . "AAPL")))))))

(ert-deftest alpaca-broker-watchlists-test-delete-watchlist-by-name-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-delete-watchlist-by-name-sync "Core"))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-watchlists-test--paper
                              "/v2/watchlists:by_name?name=Core"))))))

(provide 'alpaca-broker-watchlists-test)
;;; alpaca-broker-watchlists-test.el ends here
