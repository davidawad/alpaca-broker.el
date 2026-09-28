;;; alpaca-broker-data-news.el --- News market-data endpoint for alpaca-broker.el -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Keywords: comm, tools

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Alpaca's news market-data client (https://data.alpaca.markets/v1beta1/news).
;;
;; `alpaca-broker-news' / `-sync' fetch a single page; `-all-sync'
;; auto-paginates via `alpaca-broker--fetch-all-pages-sync' -- same
;; conventions as `alpaca-broker-data-stocks.el'.
;;
;; Requires `alpaca-broker.el' to already be loaded or on `load-path'.

;;; Code:

(require 'alpaca-broker)

;;;###autoload
(defun alpaca-broker-news (callback &optional params)
  "Fetch news articles and call CALLBACK.
PARAMS is an optional alist of Alpaca's own `GET /v1beta1/news' query
parameters (`start', `end', `sort', `symbols', `limit',
`include_content', `exclude_contentless', `page_token'), passed
straight through.  CALLBACK is called with the raw parsed JSON alist (a
single page -- see `alpaca-broker-news-all-sync' to fetch every page)."
  (alpaca-broker--request-async
   alpaca-broker--data-api-root "GET" "/v1beta1/news" params nil callback))

(defun alpaca-broker-news-sync (&optional params)
  "Fetch and return one page of news articles.
Synchronous form of `alpaca-broker-news'; see it for PARAMS."
  (alpaca-broker--request-sync
   alpaca-broker--data-api-root "GET" "/v1beta1/news" params))

(defun alpaca-broker-news-all-sync (&optional params)
  "Fetch and return every page of news articles.
Auto-paginating form of `alpaca-broker-news-sync'; PARAMS as
there.  Returns the merged
list of articles across all pages."
  (alpaca-broker--fetch-all-pages-sync
   (lambda (token)
     (alpaca-broker-news-sync (cons (cons "page_token" token) params)))
   (lambda (acc page) (alpaca-broker--merge-flat-list-pages acc page 'news))))

(provide 'alpaca-broker-data-news)
;;; alpaca-broker-data-news.el ends here
