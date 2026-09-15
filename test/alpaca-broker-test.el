;;; alpaca-broker-test.el --- Tests for alpaca-broker.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; ERT tests for alpaca-broker.el/alpaca-broker-data.el/
;; alpaca-broker-trading.el.  Mocks at the
;; `url-retrieve'/`url-retrieve-synchronously' boundary (never makes a
;; real network call), covering: request construction (headers, paper
;; vs live host selection, query params), response parsing on canned
;; JSON, error signaling on 4xx/5xx, and credential precedence
;; (defcustom > auth-source > env).
;;
;; Run via this repo's config/terminal/emacs/test/run-tests.sh, which
;; wires this plugin's implementation files and this test file in --
;; do not hand-assemble an ad-hoc `emacs --batch' invocation (see
;; docs/solutions/conventions/always-use-run-tests-sh-never-hand-
;; assemble-ad-hoc-emacs-batch.md in the parent dotfiles repo; that
;; convention is external to this standalone package).
;;
;; Standalone (outside that harness): from this directory,
;;   emacs -Q --batch -L .. -l ../alpaca-broker.el \
;;     -l ../alpaca-broker-data.el -l ../alpaca-broker-trading.el \
;;     -l alpaca-broker-test.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'url-http)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(add-to-list
 'load-path
 (file-name-directory
  (directory-file-name
   (file-name-directory (or load-file-name buffer-file-name)))))
(require 'alpaca-broker)
(require 'alpaca-broker-data)
(require 'alpaca-broker-trading)

(defun alpaca-broker-test--fake-response-buffer (status body)
  "Build a fake `url-retrieve'-style response buffer reporting STATUS
with BODY as its (already-past-the-headers) content."
  (let ((buf (generate-new-buffer " *alpaca-broker-test*")))
    (with-current-buffer buf
      (insert
       (format
        "HTTP/1.1 %d OK\r\nContent-Type: application/json\r\n\r\n%s"
        status body))
      (set (make-local-variable 'url-http-response-status) status))
    buf))

(defmacro alpaca-broker-test--with-credentials (key secret &rest body)
  "Run BODY with `alpaca-broker-api-key'/`alpaca-broker-api-secret'
bound to KEY/SECRET, so request-construction tests never touch
`auth-source' or the environment."
  (declare (indent 2))
  `(let ((alpaca-broker-api-key ,key) (alpaca-broker-api-secret ,secret))
     ,@body))

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

;; -- response parsing --

(ert-deftest alpaca-broker-request-sync-parses-canned-quote-json ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200
                    "{\"symbol\":\"AAPL\",\"quote\":{\"bp\":150.1,\"ap\":150.3}}"))))
        (let ((result (alpaca-broker-latest-quote-sync "AAPL")))
          (should (equal (alist-get 'symbol result) "AAPL"))
          (should (equal (alist-get 'bp (alist-get 'quote result)) 150.1))
          (should (equal (alist-get 'ap (alist-get 'quote result)) 150.3))))))

(ert-deftest alpaca-broker-request-sync-empty-body-returns-nil ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer 200 ""))))
        (should (null (alpaca-broker--request-sync
                       "https://data.alpaca.markets" "GET"
                       "/v2/stocks/AAPL/quotes/latest"))))))

(ert-deftest alpaca-broker-crypto-latest-quote-sync-unwraps-symbol-map ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200
                    "{\"quotes\":{\"BTC/USD\":{\"bp\":50000,\"ap\":50010}}}"))))
        (let ((result (alpaca-broker-crypto-latest-quote-sync "BTC/USD")))
          (should (equal (alist-get 'bp result) 50000))
          (should (equal (alist-get 'ap result) 50010))))))

(ert-deftest alpaca-broker-positions-sync-parses-array-response ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200
                    "[{\"symbol\":\"AAPL\",\"qty\":\"10\"},{\"symbol\":\"MSFT\",\"qty\":\"5\"}]"))))
        (let ((result (alpaca-broker-positions-sync)))
          (should (= (length result) 2))
          (should (equal (alist-get 'symbol (car result)) "AAPL"))
          (should (equal (alist-get 'symbol (cadr result)) "MSFT"))))))

(ert-deftest alpaca-broker-account-sync-parses-object-response ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve-synchronously)
                 (lambda (&rest _)
                   (alpaca-broker-test--fake-response-buffer
                    200 "{\"id\":\"acc-1\",\"cash\":\"1000.00\"}"))))
        (let ((result (alpaca-broker-account-sync)))
          (should (equal (alist-get 'id result) "acc-1"))
          (should (equal (alist-get 'cash result) "1000.00"))))))

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
           "https://data.alpaca.markets" "GET" "/v2/account" nil
           (lambda (result) (setq captured result)))
          (should (equal (alist-get 'ok captured) t))))))

(ert-deftest alpaca-broker-request-async-signals-on-error-status ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (cl-letf (((symbol-function 'url-retrieve)
                 (lambda (_url callback &rest _)
                   (funcall callback (list :error '(error http 500))))))
        (should-error
         (alpaca-broker--request-async
          "https://data.alpaca.markets" "GET" "/v2/account" nil
          (lambda (_result) nil))
         :type 'alpaca-broker-error))))

;; -- orders params pass-through --

(ert-deftest alpaca-broker-orders-sync-passes-params-through ()
  (alpaca-broker-test--with-credentials
      "k" "s"
      (let (seen-url)
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (url &rest _)
                     (setq seen-url url)
                     (alpaca-broker-test--fake-response-buffer 200 "[]"))))
          (alpaca-broker-orders-sync '(("status" . "all") ("limit" . "10")))
          (should
           (equal seen-url
                  (concat (alpaca-broker--trading-api-root)
                          "/v2/orders?status=all&limit=10")))))))

(provide 'alpaca-broker-test)
;;; alpaca-broker-test.el ends here
