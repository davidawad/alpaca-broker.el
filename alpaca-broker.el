;;; alpaca-broker.el --- Pure-Elisp client for the Alpaca Markets API -*- lexical-binding: t; -*-

;; Author: Your Name <you@example.com>
;; Maintainer: Your Name <you@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: comm, tools
;; URL: https://github.com/your-username/alpaca-broker.el

;; This file is not part of GNU Emacs.

;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; A pure-Elisp client for the Alpaca Markets API
;; (https://alpaca.markets), covering the market-data endpoints
;; (https://data.alpaca.markets) and a read-only slice of the trading
;; endpoints (https://api.alpaca.markets / https://paper-api.alpaca.markets).
;;
;; No external Elisp dependencies: HTTP goes through the built-in
;; `url.el' (`url-retrieve' for async calls, `url-retrieve-synchronously'
;; for blocking calls), and JSON is parsed with the built-in
;; `json-parse-buffer'.
;;
;; This file (`alpaca-broker.el') is the core: defcustoms, credential
;; resolution, and the shared HTTP/JSON/error plumbing.  The actual API
;; surface lives in the sibling files `alpaca-broker-data.el' (market
;; data: quotes, trades, bars, stocks and crypto) and
;; `alpaca-broker-trading.el' (read-only account/positions/orders).
;; Load all three, or just `require' `alpaca-broker-data' /
;; `alpaca-broker-trading' directly -- each requires this file itself.
;;
;; Credentials: an Alpaca API key/secret pair.  Resolved, in order:
;;
;;   1. `alpaca-broker-api-key' / `alpaca-broker-api-secret', if both
;;      are set;
;;   2. an `auth-source' entry for host `alpaca-broker-auth-source-host'
;;      (default \"data.alpaca.markets\") whose `login' field holds the
;;      key ID and whose `password'/`secret' field holds the secret key
;;      -- e.g. a line in ~/.authinfo.gpg:
;;
;;        machine data.alpaca.markets login AKFZEXAMPLEKEYID password ExampleSecretKeyGoesHere
;;
;;   3. the environment variables `ALPACA_API_PAPER_KEY' /
;;      `ALPACA_API_PAPER_SECRET' when `alpaca-broker-paper' is
;;      non-nil, else `ALPACA_API_KEY' / `ALPACA_API_SECRET'.
;;
;; The same key/secret pair authenticates both the market-data API and
;; whichever trading API `alpaca-broker-paper' selects -- Alpaca does
;; not use separate credentials for paper vs live, only a different
;; base URL.
;;
;; Errors: any HTTP response outside the 2xx range signals
;; `alpaca-broker-error' with `(STATUS BODY-EXCERPT)' as its error data
;; -- callers never see a raw `url.el' condition.

;;; Code:

(require 'url)
(require 'url-http)
(require 'json)
(require 'auth-source)
(require 'subr-x)
(require 'seq)

(defgroup alpaca-broker nil
  "Client for the Alpaca Markets trading and market-data APIs."
  :group 'comm
  :prefix "alpaca-broker-")

(defcustom alpaca-broker-paper t
  "Non-nil to talk to Alpaca's paper-trading environment.

Controls two things.  First, which trading API host
`alpaca-broker--trading-api-root' resolves to: the paper host
`https://paper-api.alpaca.markets' when non-nil, else the live host
`https://api.alpaca.markets'.  Second, which pair of environment
variables the env-var credential fallback reads: `ALPACA_API_PAPER_KEY'
and `ALPACA_API_PAPER_SECRET' when non-nil, else `ALPACA_API_KEY' and
`ALPACA_API_SECRET'.  Market data (`https://data.alpaca.markets') is
unaffected -- Alpaca serves the same data API regardless of paper vs
live."
  :type 'boolean
  :group 'alpaca-broker)

(defcustom alpaca-broker-auth-source-host "data.alpaca.markets"
  "Host to look up in `auth-source' for Alpaca credentials.

Expects a single `auth-source' entry for this host whose `login' field
holds the Alpaca API key ID and whose `password' (secret) field holds
the Alpaca API secret key, e.g. a single line (wrapped here for width)
in ~/.authinfo.gpg:

  machine data.alpaca.markets login AKFZEXAMPLEKEYID password
  ExampleSecretKeyGoesHere

Only consulted when `alpaca-broker-api-key'/`alpaca-broker-api-secret'
are not both set; see `alpaca-broker--credentials'."
  :type 'string
  :group 'alpaca-broker)

(defcustom alpaca-broker-api-key nil
  "Alpaca API key ID, overriding `auth-source' and the environment.

Leave nil to resolve the key from `auth-source' (host
`alpaca-broker-auth-source-host') or, failing that, from the
environment -- see `alpaca-broker--credentials'.  Must be set together
with `alpaca-broker-api-secret'; setting only one of the pair is
treated as neither being set."
  :type '(choice (const :tag "Not set" nil) string)
  :group 'alpaca-broker)

(defcustom alpaca-broker-api-secret nil
  "Alpaca API secret key, overriding `auth-source' and the environment.

See `alpaca-broker-api-key'."
  :type '(choice (const :tag "Not set" nil) string)
  :group 'alpaca-broker)

(defcustom alpaca-broker-timeout 30
  "HTTP request timeout in seconds, for synchronous requests."
  :type 'integer
  :group 'alpaca-broker)

(defconst alpaca-broker--data-api-root "https://data.alpaca.markets"
  "Base URL of Alpaca's market-data API.")

(defconst alpaca-broker--trading-api-root-live
  "https://api.alpaca.markets"
  "Base URL of Alpaca's live-trading API.")

(defconst alpaca-broker--trading-api-root-paper
  "https://paper-api.alpaca.markets"
  "Base URL of Alpaca's paper-trading API.")

(define-error 'alpaca-broker-error "Alpaca API error")

;; `url-http-response-status' is `url-http.el''s own runtime dynamic
;; variable, bound in the response buffer -- not defined via a
;; top-level `defvar' there in a way the byte-compiler picks up from a
;; plain `(require 'url-http)'.  This declaration is a byte-compiler
;; satisfier only.
(defvar url-http-response-status)

;; -- credential resolution --

(defun alpaca-broker--env-var-names ()
  "Return the environment variable names for Alpaca credentials.
Result is (KEY-VAR . SECRET-VAR), selected by `alpaca-broker-paper'."
  (if alpaca-broker-paper
      (cons "ALPACA_API_PAPER_KEY" "ALPACA_API_PAPER_SECRET")
    (cons "ALPACA_API_KEY" "ALPACA_API_SECRET")))

(defun alpaca-broker--auth-source-credentials ()
  "Return Alpaca credentials from `auth-source', or nil.
Result is (KEY . SECRET) from an `auth-source' entry for
`alpaca-broker-auth-source-host', or nil if no such entry exists (or
it is missing either field)."
  (when-let* ((found
               (car
                (auth-source-search
                 :host alpaca-broker-auth-source-host
                 :max 1)))
              (key (plist-get found :user))
              (secret-slot (plist-get found :secret))
              (secret
               (if (functionp secret-slot)
                   (funcall secret-slot)
                 secret-slot)))
    (cons key secret)))

(defun alpaca-broker--env-credentials ()
  "Return Alpaca credentials from the environment, or nil.
Result is (KEY . SECRET) from the environment variables selected by
`alpaca-broker-paper' (see `alpaca-broker--env-var-names'), or nil if
either is unset or empty."
  (pcase-let ((`(,key-var . ,secret-var)
               (alpaca-broker--env-var-names)))
    (let ((key (getenv key-var))
          (secret (getenv secret-var)))
      (when (and key
                 (not (string-empty-p key))
                 secret
                 (not (string-empty-p secret)))
        (cons key secret)))))

(defun alpaca-broker--credentials ()
  "Resolve Alpaca credentials as (KEY . SECRET).
Tried in order: `alpaca-broker-api-key'/`alpaca-broker-api-secret' if
both are set, else an `auth-source' entry for
`alpaca-broker-auth-source-host', else the environment variables named
by `alpaca-broker--env-var-names'.  Signals a `user-error' with setup
instructions if none of the three resolves."
  (or
   (and alpaca-broker-api-key
        alpaca-broker-api-secret
        (cons alpaca-broker-api-key alpaca-broker-api-secret))
   (alpaca-broker--auth-source-credentials)
   (alpaca-broker--env-credentials)
   (pcase-let ((`(,key-var . ,secret-var)
                (alpaca-broker--env-var-names)))
     (user-error
      "Alpaca credentials not found: set `alpaca-broker-api-key'/`alpaca-broker-api-secret', add an auth-source entry (login/password) for host `%s', or set %s/%s"
      alpaca-broker-auth-source-host key-var secret-var))))

;; -- host selection --

(defun alpaca-broker--trading-api-root ()
  "Return the trading-API base URL selected by `alpaca-broker-paper'."
  (if alpaca-broker-paper
      alpaca-broker--trading-api-root-paper
    alpaca-broker--trading-api-root-live))

;; -- URL/query-string construction --

(defun alpaca-broker--query-string (params)
  "Return PARAMS as a percent-encoded HTTP query string.
PARAMS is an alist of string/symbol keys to string values; pairs whose
value is nil are dropped.  Returns the empty string when PARAMS has no
non-nil values."
  (mapconcat (lambda (pair)
               (concat
                (url-hexify-string (format "%s" (car pair)))
                "="
                (url-hexify-string (format "%s" (cdr pair)))))
             (seq-filter #'cdr params)
             "&"))

(defun alpaca-broker--url (host path params)
  "Build the full request URL for HOST and PATH.
Appends PARAMS (see `alpaca-broker--query-string') as a `?'-prefixed
query string when non-empty."
  (let ((query (alpaca-broker--query-string params)))
    (concat
     host path
     (unless (string-empty-p query)
       (concat "?" query)))))

(defun alpaca-broker--headers ()
  "Return the `url-request-extra-headers' alist for an authenticated request.
Resolves credentials via `alpaca-broker--credentials'."
  (let ((credentials (alpaca-broker--credentials)))
    `(("APCA-API-KEY-ID" . ,(car credentials))
      ("APCA-API-SECRET-KEY" . ,(cdr credentials))
      ("Accept" . "application/json"))))

;; -- JSON/error boundary --

(defun alpaca-broker--truncate-string (string limit)
  "Return STRING truncated to LIMIT characters.
Appends a trailing `...' marker when truncation actually happened."
  (if (> (length string) limit)
      (concat (substring string 0 limit) "...")
    string))

(defun alpaca-broker--parse-json-at-point ()
  "Parse the JSON value starting at point in the current buffer.
Returns an alist-of-alists structure, or nil for an empty body."
  (if (eobp)
      nil
    (json-parse-buffer
     :object-type 'alist
     :array-type 'list
     :null-object nil
     :false-object
     :false)))

(defun alpaca-broker--signal-http-error (status)
  "Signal `alpaca-broker-error' for an HTTP response whose status is STATUS.
Uses the current buffer's remaining contents (from point to
`point-max') as the body excerpt."
  (let ((body
         (alpaca-broker--truncate-string
          (string-trim (buffer-substring (point) (point-max))) 300)))
    (signal 'alpaca-broker-error (list status body))))

(defun alpaca-broker--handle-response-buffer (buffer)
  "Parse BUFFER, a `url.el' response buffer, into a JSON alist.
BUFFER is a `url-retrieve'/`url-retrieve-synchronously' response
buffer.  Returns the parsed alist on a 2xx status, else signals
`alpaca-broker-error' via `alpaca-broker--signal-http-error'.  Kills
BUFFER before returning."
  (unwind-protect
      (with-current-buffer buffer
        (goto-char (point-min))
        (let ((status url-http-response-status))
          (re-search-forward "\r?\n\r?\n" nil 'move)
          (if (and status (< status 300))
              (alpaca-broker--parse-json-at-point)
            (alpaca-broker--signal-http-error status))))
    (kill-buffer buffer)))

;; -- request layer --

(defun alpaca-broker--request-sync (host method path &optional params)
  "Issue a synchronous, authenticated request and return its JSON body.
Sends a METHOD request to HOST + PATH with query PARAMS, blocking up
to `alpaca-broker-timeout' seconds.  Returns the parsed JSON alist, or
nil for an empty body.  Signals `alpaca-broker-error' on a non-2xx
response, transport failure, or timeout -- never a raw `url.el'
condition."
  (let* ((url-request-method method)
         (url-request-extra-headers (alpaca-broker--headers))
         (url (alpaca-broker--url host path params))
         (buffer
          (url-retrieve-synchronously url t t alpaca-broker-timeout)))
    (unless buffer
      (signal
       'alpaca-broker-error
       (list
        nil
        (format "request failed or timed out: %s %s" method url))))
    (alpaca-broker--handle-response-buffer buffer)))

(defun alpaca-broker--request-async (host method path params callback)
  "Issue an asynchronous, authenticated request, calling CALLBACK.
Sends a METHOD request to HOST + PATH with query PARAMS.  On success,
calls CALLBACK with one argument, the parsed JSON alist (or nil for an
empty body).  On an HTTP error or transport failure, signals
`alpaca-broker-error' from within the response callback rather than
letting a raw `url.el' condition through -- wrap CALLBACK's own body
in `condition-case' if the caller needs to react to that itself."
  (let* ((url-request-method method)
         (url-request-extra-headers (alpaca-broker--headers))
         (url (alpaca-broker--url host path params)))
    (url-retrieve
     url
     (lambda (status)
       (if-let* ((err (plist-get status :error)))
           (signal 'alpaca-broker-error (list nil (format "%S" err)))
         (funcall callback
                  (alpaca-broker--handle-response-buffer
                   (current-buffer)))))
     nil t t)))

(provide 'alpaca-broker)
;;; alpaca-broker.el ends here
