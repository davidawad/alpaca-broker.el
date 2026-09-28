;;; alpaca-broker-data-news-test.el --- Tests for alpaca-broker-data-news.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-data-news.el'.  Each test
;; asserts the HTTP method, path, and query params of the news
;; endpoint, plus its auto-paginating `-all-sync' form.  Mocks at the
;; `url-retrieve-synchronously' boundary; never makes a real network
;; call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-data-news)

(defconst alpaca-broker-data-news-test--root "https://data.alpaca.markets")

(ert-deftest alpaca-broker-data-news-test-news-sync ()
  (let ((req (alpaca-broker-test--capture-request
               (alpaca-broker-news-sync
                '(("symbols" . "AAPL") ("limit" . "10"))))))
    (should (equal (plist-get req :method) "GET"))
    (should (equal (plist-get req :url)
                    (concat alpaca-broker-data-news-test--root
                            "/v1beta1/news?symbols=AAPL&limit=10")))))

(ert-deftest alpaca-broker-data-news-test-news-all-sync-paginates ()
  (let ((page 0))
    (cl-letf (((symbol-function 'alpaca-broker-news-sync)
               (lambda (params)
                 (setq page (1+ page))
                 (if (null (alist-get "page_token" params nil nil #'equal))
                     '((next_page_token . "tok-2") (news . (1 2)))
                   '((next_page_token . nil) (news . (3)))))))
      (should (equal (alpaca-broker-news-all-sync) '(1 2 3)))
      (should (= page 2)))))

(provide 'alpaca-broker-data-news-test)
;;; alpaca-broker-data-news-test.el ends here
