;;; alpaca-broker-test.el --- Tests for alpaca-broker.el core -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; ERT tests for alpaca-broker.el's core: credential resolution,
;; URL/query-string construction, the request layer (headers, JSON
;; body encoding, response parsing, error signaling), the order-safety
;; gate, and the pagination helpers.  Every per-endpoint request-shape
;; test lives in the sibling `alpaca-broker-*-test.el' files instead --
;; this file only exercises the shared plumbing those files build on.
;; Mocks at the `url-retrieve'/`url-retrieve-synchronously' boundary
;; (never makes a real network call).
;;
;; Run from the repo root:
;;   emacs -Q --batch -L . -L test -l test/alpaca-broker-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'alpaca-broker-test-helpers)

;; -- credential resolution --

(ert-deftest alpaca-broker-credentials-prefers-defcustom-override ()
  "defcustom override wins even when auth-source and env both have a
value too -- the top of the precedence order."
  (let ((alpaca-broker-api-key "custom-key")
        (alpaca-broker-api-secret "custom-secret"))
    (cl-letf (((symbol-function 'alpaca-broker--auth-source-credentials)
               (lambda () (cons "auth-source-key" "auth-source-secret")))
              ((symbol-function 'getenv)
               (lambda (_var) "env-value")))
      (should (equal (alpaca-broker--credentials)
                      (cons "custom-key" "custom-secret"))))))

(ert-deftest alpaca-broker-credentials-falls-back-to-auth-source ()
  "With no defcustom override, auth-source wins over the environment."
  (let ((alpaca-broker-api-key nil) (alpaca-broker-api-secret nil))
    (cl-letf (((symbol-function 'alpaca-broker--auth-source-credentials)
               (lambda () (cons "auth-source-key" "auth-source-secret")))
              ((symbol-function 'getenv)
               (lambda (_var) "env-value")))
      (should (equal (alpaca-broker--credentials)
                      (cons "auth-source-key" "auth-source-secret"))))))

(ert-deftest alpaca-broker-credentials-falls-back-to-env-when-no-auth-source ()
  "With neither a defcustom override nor an auth-source entry, the
environment variables are used -- the bottom of the precedence order."
  (let ((alpaca-broker-api-key nil)
        (alpaca-broker-api-secret nil)
        (alpaca-broker-paper t))
    (cl-letf (((symbol-function 'alpaca-broker--auth-source-credentials)
               (lambda () nil))
              ((symbol-function 'getenv)
               (lambda (var)
                 (cond ((equal var "ALPACA_API_PAPER_KEY") "env-key")
                       ((equal var "ALPACA_API_PAPER_SECRET") "env-secret")))))
      (should (equal (alpaca-broker--credentials)
                      (cons "env-key" "env-secret"))))))

(ert-deftest alpaca-broker-credentials-env-names-select-paper-vars-when-paper ()
  (let ((alpaca-broker-paper t))
    (should (equal (alpaca-broker--env-var-names)
                    (cons "ALPACA_API_PAPER_KEY" "ALPACA_API_PAPER_SECRET")))))

(ert-deftest alpaca-broker-credentials-env-names-select-live-vars-when-not-paper ()
  (let ((alpaca-broker-paper nil))
    (should (equal (alpaca-broker--env-var-names)
                    (cons "ALPACA_API_KEY" "ALPACA_API_SECRET")))))

(ert-deftest alpaca-broker-credentials-errors-when-nothing-resolves ()
  (let ((alpaca-broker-api-key nil)
        (alpaca-broker-api-secret nil)
        (alpaca-broker-paper t))
    (cl-letf (((symbol-function 'alpaca-broker--auth-source-credentials)
               (lambda () nil))
              ((symbol-function 'getenv) (lambda (_var) nil)))
      (should-error (alpaca-broker--credentials) :type 'user-error))))

(ert-deftest alpaca-broker-credentials-treats-half-set-defcustom-as-unset ()
  "Only the key set, not the secret -- must not treat this as a valid
override; falls through to the next tier."
  (let ((alpaca-broker-api-key "only-key") (alpaca-broker-api-secret nil))
    (cl-letf (((symbol-function 'alpaca-broker--auth-source-credentials)
               (lambda () (cons "as-key" "as-secret"))))
      (should (equal (alpaca-broker--credentials)
                      (cons "as-key" "as-secret"))))))

(ert-deftest alpaca-broker-auth-source-credentials-reads-user-and-secret ()
  (cl-letf (((symbol-function 'auth-source-search)
             (lambda (&rest _)
               (list (list :user "AKFZKEYID" :secret "the-secret")))))
    (should (equal (alpaca-broker--auth-source-credentials)
                    (cons "AKFZKEYID" "the-secret")))))

(ert-deftest alpaca-broker-auth-source-credentials-calls-secret-function ()
  "`auth-source' backends commonly return `:secret' as a nullary
function rather than a raw string; must be `funcall'ed."
  (cl-letf (((symbol-function 'auth-source-search)
             (lambda (&rest _)
               (list (list :user "AKFZKEYID"
                           :secret (lambda () "lazy-secret"))))))
    (should (equal (alpaca-broker--auth-source-credentials)
                    (cons "AKFZKEYID" "lazy-secret")))))

(ert-deftest alpaca-broker-auth-source-credentials-nil-when-no-entry ()
  (cl-letf (((symbol-function 'auth-source-search) (lambda (&rest _) nil)))
    (should (null (alpaca-broker--auth-source-credentials)))))

;; -- URL/query-string construction --

(ert-deftest alpaca-broker-query-string-hexifies-and-joins ()
  (should (equal (alpaca-broker--query-string
                   '(("a" . "1") ("b" . "hello world")))
                  "a=1&b=hello%20world")))

(ert-deftest alpaca-broker-query-string-drops-nil-values ()
  (should (equal (alpaca-broker--query-string
                   '(("a" . "1") ("b" . nil) ("c" . "3")))
                  "a=1&c=3")))

(ert-deftest alpaca-broker-query-string-empty-when-no-params ()
  (should (equal (alpaca-broker--query-string nil) "")))

(ert-deftest alpaca-broker-url-appends-query-string-when-present ()
  (should (equal (alpaca-broker--url "https://data.alpaca.markets"
                                       "/v2/stocks/AAPL"
                                       '(("limit" . "5")))
                  "https://data.alpaca.markets/v2/stocks/AAPL?limit=5")))

(ert-deftest alpaca-broker-url-omits-question-mark-when-no-params ()
  (should (equal (alpaca-broker--url "https://data.alpaca.markets"
                                       "/v2/stocks/AAPL"
                                       nil)
                  "https://data.alpaca.markets/v2/stocks/AAPL")))

(ert-deftest alpaca-broker-join-symbols-passes-through-a-string ()
  (should (equal (alpaca-broker--join-symbols "AAPL,MSFT") "AAPL,MSFT")))

(ert-deftest alpaca-broker-join-symbols-joins-a-list-with-commas ()
  (should (equal (alpaca-broker--join-symbols '("AAPL" "MSFT")) "AAPL,MSFT")))

;; -- host selection (paper vs live) --

(ert-deftest alpaca-broker-trading-api-root-is-paper-host-by-default ()
  (let ((alpaca-broker-paper t))
    (should (equal (alpaca-broker--trading-api-root)
                    "https://paper-api.alpaca.markets"))))

(ert-deftest alpaca-broker-trading-api-root-is-live-host-when-not-paper ()
  (let ((alpaca-broker-paper nil))
    (should (equal (alpaca-broker--trading-api-root)
                    "https://api.alpaca.markets"))))

;; -- request construction: headers --

(ert-deftest alpaca-broker-request-sync-sends-key-and-secret-headers ()
  (alpaca-broker-test--with-credentials
      "AKFZKEYID" "secretvalue"
      (let (seen-headers)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _)
                     (setq seen-headers url-request-extra-headers)
                     (alpaca-broker-test--fake-response-buffer 200 "{}"))))
          (alpaca-broker--request-sync "https://data.alpaca.markets" "GET"
                                        "/v2/account")
          (should (equal (cdr (assoc "APCA-API-KEY-ID" seen-headers))
                          "AKFZKEYID"))
          (should (equal (cdr (assoc "APCA-API-SECRET-KEY" seen-headers))
                          "secretvalue"))))))

(ert-deftest alpaca-broker-request-sync-sends-method-and-url-with-params ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-method seen-url)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (url &rest _)
                     (setq seen-url url seen-method url-request-method)
                     (alpaca-broker-test--fake-response-buffer 200 "{}"))))
          (alpaca-broker--request-sync "https://api.alpaca.markets" "GET"
                                        "/v2/orders"
                                        '(("status" . "open")))
          (should (equal seen-method "GET"))
          (should
           (equal seen-url
                  "https://api.alpaca.markets/v2/orders?status=open"))))))

(ert-deftest alpaca-broker-request-sync-json-encodes-body-and-sets-content-type ()
  "A non-nil BODY is JSON-encoded onto `url-request-data' and adds a
JSON `Content-Type' header -- the plumbing every order-mutating and
watchlist-mutating endpoint relies on."
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-data seen-headers)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _)
                     (setq seen-data url-request-data
                           seen-headers url-request-extra-headers)
                     (alpaca-broker-test--fake-response-buffer 200 "{}"))))
          (alpaca-broker--request-sync "https://api.alpaca.markets" "POST"
                                        "/v2/orders" nil
                                        '(("symbol" . "SPY") ("qty" . "1")))
          (should (equal (cdr (assoc "Content-Type" seen-headers))
                          "application/json"))
          (should (equal (alpaca-broker-test--decode-body seen-data)
                          '((symbol . "SPY") (qty . "1"))))))))

(ert-deftest alpaca-broker-request-sync-omits-content-type-when-no-body ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-headers)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _)
                     (setq seen-headers url-request-extra-headers)
                     (alpaca-broker-test--fake-response-buffer 200 "{}"))))
          (alpaca-broker--request-sync "https://api.alpaca.markets" "GET"
                                        "/v2/account")
          (should (null (assoc "Content-Type" seen-headers)))))))

;; -- response parsing --

(ert-deftest alpaca-broker-request-sync-parses-canned-object-json ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200
                    "{\"symbol\":\"AAPL\",\"quote\":{\"bp\":150.1,\"ap\":150.3}}"))))
        (let ((result (alpaca-broker--request-sync
                       "https://data.alpaca.markets" "GET"
                       "/v2/stocks/AAPL/quotes/latest")))
          (should (equal (alist-get 'symbol result) "AAPL"))
          (should (equal (alist-get 'bp (alist-get 'quote result)) 150.1))
          (should (equal (alist-get 'ap (alist-get 'quote result)) 150.3))))))

(ert-deftest alpaca-broker-request-sync-parses-canned-array-json ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200
                    "[{\"symbol\":\"AAPL\",\"qty\":\"10\"},{\"symbol\":\"MSFT\",\"qty\":\"5\"}]"))))
        (let ((result (alpaca-broker--request-sync
                       "https://paper-api.alpaca.markets" "GET"
                       "/v2/positions")))
          (should (= (length result) 2))
          (should (equal (alist-get 'symbol (car result)) "AAPL"))
          (should (equal (alist-get 'symbol (cadr result)) "MSFT"))))))

(ert-deftest alpaca-broker-request-sync-empty-body-returns-nil ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer 200 ""))))
        (should (null (alpaca-broker--request-sync
                       "https://data.alpaca.markets" "GET"
                       "/v2/stocks/AAPL/quotes/latest"))))))

(ert-deftest alpaca-broker-request-sync-binary-returns-raw-body ()
  "Returns the response body verbatim -- not JSON-parsed -- for a
binary-payload endpoint like the logo fetcher."
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200 "FAKE-PNG-BYTES-NOT-JSON"))))
        (should (equal (alpaca-broker--request-sync-binary
                        "https://data.alpaca.markets" "GET"
                        "/v1beta1/logos/AAPL")
                       "FAKE-PNG-BYTES-NOT-JSON")))))

;; -- error signaling --

(ert-deftest alpaca-broker-request-sync-401-signals-alpaca-broker-error ()
  (alpaca-broker-test--with-credentials
      "bad" "creds"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    401 "{\"message\":\"unauthorized\"}"))))
        (let ((err (should-error (alpaca-broker--request-sync
                                   "https://api.alpaca.markets" "GET"
                                   "/v2/account")
                                  :type 'alpaca-broker-error)))
          (should (= (nth 1 err) 401))
          (should (string-match-p "unauthorized" (nth 2 err)))))))

(ert-deftest alpaca-broker-request-sync-500-signals-alpaca-broker-error ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    500 "internal error"))))
        (should-error (alpaca-broker--request-sync
                       "https://api.alpaca.markets" "GET" "/v2/account")
                       :type 'alpaca-broker-error))))

(ert-deftest alpaca-broker-request-sync-nil-buffer-signals-alpaca-broker-error ()
  "A nil return from `url-retrieve-synchronously' (transport failure /
timeout) must surface as `alpaca-broker-error', not an unbound-buffer
error."
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _) nil)))
        (should-error (alpaca-broker--request-sync
                       "https://api.alpaca.markets" "GET" "/v2/account")
                       :type 'alpaca-broker-error))))

(ert-deftest alpaca-broker-truncate-string-truncates-long-bodies ()
  (should (equal (alpaca-broker--truncate-string "abcdef" 3) "abc...")))

(ert-deftest alpaca-broker-truncate-string-passes-through-short-bodies ()
  (should (equal (alpaca-broker--truncate-string "abc" 10) "abc")))

;; -- async request layer --

(ert-deftest alpaca-broker-request-async-calls-callback-with-parsed-json ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (captured)
        (cl-letf (((symbol-function 'url-retrieve)
                   (lambda (_url callback &rest _)
                     (let ((buf (alpaca-broker-test--fake-response-buffer
                                 200 "{\"ok\":true}")))
                       (with-current-buffer buf
                         (funcall callback nil))))))
          (alpaca-broker--request-async
           "https://data.alpaca.markets" "GET" "/v2/account" nil nil
           (lambda (result) (setq captured result)))
          (should (equal (alist-get 'ok captured) t))))))

(ert-deftest alpaca-broker-request-async-json-encodes-body ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-data)
        (cl-letf (((symbol-function 'url-retrieve)
                   (lambda (_url callback &rest _)
                     (setq seen-data url-request-data)
                     (let ((buf (alpaca-broker-test--fake-response-buffer
                                 200 "{}")))
                       (with-current-buffer buf
                         (funcall callback nil))))))
          (alpaca-broker--request-async
           "https://api.alpaca.markets" "POST" "/v2/orders" nil
           '(("symbol" . "SPY")) (lambda (_result) nil))
          (should (equal (alpaca-broker-test--decode-body seen-data)
                          '((symbol . "SPY"))))))))

(ert-deftest alpaca-broker-request-async-signals-on-error-status ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve)
                 (lambda (_url callback &rest _)
                   (funcall callback (list :error '(error http 500))))))
        (should-error
         (alpaca-broker--request-async
          "https://data.alpaca.markets" "GET" "/v2/account" nil nil
          (lambda (_result) nil))
         :type 'alpaca-broker-error))))

;; -- order-safety gate --

(ert-deftest alpaca-broker-require-order-permission-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker--require-order-permission 'some-fn)
                  :type 'user-error)))

(ert-deftest alpaca-broker-require-order-permission-allows-when-enabled ()
  (let ((alpaca-broker-allow-orders t))
    (should (null (alpaca-broker--require-order-permission 'some-fn)))))

;; -- pagination helpers --

(ert-deftest alpaca-broker-fetch-all-pages-sync-stops-at-nil-token ()
  (let* ((pages '(((next_page_token . "tok-1") (items . (1 2)))
                  ((next_page_token . nil) (items . (3)))))
         (calls 0))
    (should
     (equal
      (alpaca-broker--fetch-all-pages-sync
       (lambda (_token)
         (prog1 (nth calls pages) (setq calls (1+ calls))))
       (lambda (acc page) (append acc (alist-get 'items page))))
      '(1 2 3)))
    (should (= calls 2))))

(ert-deftest alpaca-broker-fetch-all-pages-sync-stops-at-false-token ()
  "Alpaca's JSON `null' decodes to nil already, but guard against a
literal `:false' token too, since `json-parse-buffer' is configured
with a `:false-object' of `:false' elsewhere in this package."
  (let* ((pages '(((next_page_token . :false) (items . (1))))))
    (should
     (equal
      (alpaca-broker--fetch-all-pages-sync
       (lambda (_token) (car pages))
       (lambda (acc page) (append acc (alist-get 'items page))))
      '(1)))))

(ert-deftest alpaca-broker-merge-keyed-list-pages-appends-per-key ()
  (let ((acc (alpaca-broker--merge-keyed-list-pages
              nil '((bars . ((AAPL . (1 2))))) 'bars)))
    (setq acc (alpaca-broker--merge-keyed-list-pages
               acc '((bars . ((AAPL . (3)) (MSFT . (9))))) 'bars))
    (should (equal (alist-get 'AAPL acc) '(1 2 3)))
    (should (equal (alist-get 'MSFT acc) '(9)))))

(ert-deftest alpaca-broker-merge-keyed-object-pages-overwrites-per-key ()
  (let ((acc (alpaca-broker--merge-keyed-object-pages
              nil '((snapshots . ((AAPL . old)))) 'snapshots)))
    (setq acc (alpaca-broker--merge-keyed-object-pages
               acc '((snapshots . ((AAPL . new) (MSFT . m)))) 'snapshots))
    (should (equal (alist-get 'AAPL acc) 'new))
    (should (equal (alist-get 'MSFT acc) 'm))))

(ert-deftest alpaca-broker-merge-flat-list-pages-concatenates-in-order ()
  (let ((acc (alpaca-broker--merge-flat-list-pages
              nil '((news . (1 2))) 'news)))
    (setq acc (alpaca-broker--merge-flat-list-pages
               acc '((news . (3))) 'news))
    (should (equal acc '(1 2 3)))))

(provide 'alpaca-broker-test)
;;; alpaca-broker-test.el ends here
