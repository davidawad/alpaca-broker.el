;;; alpaca-broker-test-helpers.el --- Shared ERT test doubles -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Shared test doubles for alpaca-broker.el's per-endpoint mocked ERT
;; suites (test/alpaca-broker-*-test.el).  Defines no `ert-deftest'
;; forms itself -- every test file `require's it, so it is loaded
;; alongside them under CI's `test/*.el' glob without needing its own
;; entry there.
;;
;; Mocks entirely at the `url-retrieve'/`url-retrieve-synchronously'
;; boundary -- no real network call is ever made.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'url-http)
(require 'json)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(add-to-list
 'load-path
 (file-name-directory
  (directory-file-name
   (file-name-directory (or load-file-name buffer-file-name)))))
(require 'alpaca-broker)

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

(defmacro alpaca-broker-test--capture-request (&rest body)
  "Run BODY, capturing the synchronous request it issues.
Binds test credentials (see `alpaca-broker-test--with-credentials')
and mocks `url-retrieve-synchronously' to return a canned 200 `{}'
response while capturing the request it was called with.  Returns a
plist `(:method METHOD :url URL :data DATA)' -- DATA is the raw
JSON-encoded request-body string, or nil for a bodyless request.
BODY should call exactly one `alpaca-broker-FOO-sync' fetcher."
  (declare (indent 0))
  `(alpaca-broker-test--with-credentials
       "AKFZKEYID" "secretvalue"
     (let (captured)
       (cl-letf (((symbol-function 'url-retrieve-synchronously)
                  (lambda (url &rest _)
                    (setq captured
                          (list :method url-request-method
                                :url url
                                :data url-request-data))
                    (alpaca-broker-test--fake-response-buffer 200 "{}"))))
         ,@body)
       captured)))

(defmacro alpaca-broker-test--capture-request-with-response (response &rest body)
  "Like `alpaca-broker-test--capture-request', but the canned 200
response body is RESPONSE (a JSON string) instead of `{}', and the
captured plist gains a `:result' key holding BODY's return value."
  (declare (indent 1))
  `(alpaca-broker-test--with-credentials
       "AKFZKEYID" "secretvalue"
     (let (captured result)
       (cl-letf (((symbol-function 'url-retrieve-synchronously)
                  (lambda (url &rest _)
                    (setq captured
                          (list :method url-request-method
                                :url url
                                :data url-request-data))
                    (alpaca-broker-test--fake-response-buffer 200 ,response))))
         (setq result (progn ,@body)))
       (setq captured (plist-put captured :result result))
       captured)))

(defun alpaca-broker-test--decode-body (data)
  "Decode DATA, a JSON request-body string (or nil), into an alist."
  (and data
       (json-parse-string
        data :object-type 'alist :array-type 'list
        :null-object nil :false-object :false)))

(provide 'alpaca-broker-test-helpers)
;;; alpaca-broker-test-helpers.el ends here
