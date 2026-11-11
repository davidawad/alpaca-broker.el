;;; alpaca-broker-model-test.el --- Tests for alpaca-broker-model.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Offline, pure.  Needs the sibling broker-model.el package, found via
;; $BROKER_MODEL_DIR or ../broker-model.el next to this repo; without
;; it every test here is skipped.  The cross-broker test also needs
;; ../schwab-broker.el (or $SCHWAB_BROKER_DIR) and skips without it.
;;
;; Vectors come from Alpaca's own docs (captures in docs/margin/): the
;; sample account object (Trading Account page), the maintenance table
;; and concentration rule (Margin and Short Selling), the universal
;; spread rule and cost-basis examples (Options Level 3 Trading), and
;; the options levels.

;;; Code:

(require 'ert)
(require 'cl-lib)

(let* ((here (file-name-directory (or load-file-name buffer-file-name)))
       (root (file-name-directory (directory-file-name here))))
  (add-to-list 'load-path root)
  (dolist (d (list (or (getenv "BROKER_MODEL_DIR") (expand-file-name "../broker-model.el" root))
                   (or (getenv "SCHWAB_BROKER_DIR") (expand-file-name "../schwab-broker.el" root))))
    (when (file-directory-p d) (add-to-list 'load-path d t))))

(defvar alpaca-broker-model-test--ok (ignore-errors (require 'alpaca-broker-model)))

(declare-function broker-model-requirement "broker-model")
(declare-function broker-model-account "broker-model")
(declare-function broker-model-compare "broker-model")
(declare-function broker-model-resolve "broker-model-core")
(declare-function broker-model-day-trade-check "broker-model")
(declare-function alpaca-broker-model-required-level "alpaca-broker-model")

(defmacro alpaca-broker-model-test--deftest (name doc &rest body)
  "Define ERT test NAME (DOC) running BODY, skipped without broker-model."
  (declare (indent 1) (doc-string 2))
  `(ert-deftest ,name ()
     ,doc
     (skip-unless alpaca-broker-model-test--ok)
     ,@body))

(defun alpaca-broker-model-test--near (a b &optional tol)
  "Non-nil when A and B differ by at most TOL (default 0.01)."
  (<= (abs (- a b)) (or tol 0.01)))

(defun alpaca-broker-model-test--req (pos &optional acct)
  "Alpaca requirement of POS in ACCT (default margin)."
  (broker-model-requirement 'alpaca (or acct 'margin) pos))

(alpaca-broker-model-test--deftest alpaca-broker-model-sample-account
  "Trading Account sample object: cash -23,140.2, long MV 126,960.76 ->
initial_margin 63,480.38, maintenance_margin 38,088.228, regt_buying_power
80,680.36, buying_power (multiplier 4) 262,113.632 from last_equity
103,529.24 and last_maintenance_margin 38,000.832."
  (let ((a (broker-model-account 'alpaca 'margin :cash -23140.2
                                 :positions '((:type stock :symbol "AAA" :price 126.96076 :qty 1000))
                                 :last-equity 103529.24 :last-maintenance 38000.832)))
    (should (alpaca-broker-model-test--near (plist-get a :equity) 103820.56))
    (should (alpaca-broker-model-test--near (plist-get a :initial-requirement) 63480.38))
    (should (alpaca-broker-model-test--near (plist-get a :maintenance-requirement) 38088.228))
    (should (alpaca-broker-model-test--near (plist-get a :stock-bp) 80680.36))
    (should (alpaca-broker-model-test--near (plist-get a :intraday-bp) 262113.632))))

(alpaca-broker-model-test--deftest alpaca-broker-model-maintenance-table
  "Margin doc table: long < $2.50 100%, $2.50-$6 50%, > $6 30%; 2x 50%, 3x 75%;
short < $5 greater of $2.50/share or 100%, >= $5 greater of $5/share or 30%."
  (let ((m (lambda (pos) (plist-get (alpaca-broker-model-test--req pos) :maintenance))))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "A" :price 2 :qty 100)) 200.0))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "B" :price 4 :qty 100)) 200.0))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "C" :price 10 :qty 100)) 300.0))
    (should (alpaca-broker-model-test--near
             (funcall m '(:type stock :symbol "D" :asset-class leveraged-etf :leverage 2 :price 10 :qty 100)) 500.0))
    (should (alpaca-broker-model-test--near
             (funcall m '(:type stock :symbol "E" :asset-class leveraged-etf :leverage 3 :price 10 :qty 100)) 750.0))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "F" :side short :price 2 :qty 100)) 250.0))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "G" :side short :price 3 :qty 100)) 300.0))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "H" :side short :price 10 :qty 100)) 500.0))
    (should (alpaca-broker-model-test--near (funcall m '(:type stock :symbol "I" :side short :price 100 :qty 100)) 3000.0))))

(alpaca-broker-model-test--deftest alpaca-broker-model-concentration
  "Concentrated Margin Requirements: one name >= 70% of equities and a
margin balance >= $100,000 -> 50% maintenance on that name."
  (let ((hot (broker-model-account 'alpaca 'margin :cash -150000.0
                                   :positions '((:type stock :symbol "AAA" :price 100 :qty 2800)
                                                (:type stock :symbol "BBB" :price 100 :qty 200))))
        (cool (broker-model-account 'alpaca 'margin :cash -50000.0
                                    :positions '((:type stock :symbol "AAA" :price 100 :qty 2800)
                                                 (:type stock :symbol "BBB" :price 100 :qty 200)))))
    ;; AAA 280,000 of 300,000 = 93%: 50% x 280,000 + 30% x 20,000
    (should (alpaca-broker-model-test--near (plist-get hot :maintenance-requirement) 146000.0))
    (should (alpaca-broker-model-test--near (plist-get cool :maintenance-requirement) 90000.0))))

(alpaca-broker-model-test--deftest alpaca-broker-model-universal-spread
  "Options Level 3: the four-call example (long 100, short 110, short 190,
long 200) has $0 maintenance; the 190/200 call credit spread @15/10 has
$1,000 maintenance and a $500 cost basis."
  (let ((four (alpaca-broker-model-test--req
               '(:type spread :symbol "AAPL" :expiry "2025-01-17"
                       :legs ((:side long :right call :strike 100 :price 0 :qty 1)
                              (:side short :right call :strike 110 :price 0 :qty 1)
                              (:side short :right call :strike 190 :price 0 :qty 1)
                              (:side long :right call :strike 200 :price 0 :qty 1)))))
        (cs (alpaca-broker-model-test--req
             '(:type vertical :symbol "AAPL" :right call :long-strike 200 :short-strike 190
                     :long-price 10 :short-price 15 :qty 1))))
    (should (plist-get four :allowed))
    (should (= 0.0 (plist-get four :max-loss-intrinsic)))
    (should (alpaca-broker-model-test--near (plist-get cs :max-loss-intrinsic) 1000.0))
    (should (alpaca-broker-model-test--near (plist-get cs :buying-power-effect) 500.0))
    (should (eq (plist-get cs :confidence) 'official))))

(alpaca-broker-model-test--deftest alpaca-broker-model-csp
  "Options BP check: cash-secured put needs strike x 100 - premium.  The doc
prints only 'required: 20310'; strike 205 and premium 1.90 are illustrative."
  (let ((r (alpaca-broker-model-test--req '(:type cash-secured-put :symbol "X" :strike 205 :price 1.90 :qty 1))))
    (should (alpaca-broker-model-test--near (plist-get r :buying-power-effect) 20310.0))
    (should (eq (plist-get r :confidence) 'official))))

(alpaca-broker-model-test--deftest alpaca-broker-model-levels
  "Levels 0-3: no uncovered options; calendars are uncovered per expiry."
  (should (= 1 (alpaca-broker-model-required-level 'covered-call)))
  (should (= 1 (alpaca-broker-model-required-level 'cash-secured-put)))
  (should (= 2 (alpaca-broker-model-required-level 'long-option)))
  (should (= 3 (alpaca-broker-model-required-level 'vertical-credit)))
  (should-not (alpaca-broker-model-required-level 'naked-put))
  (should-not (plist-get (alpaca-broker-model-test--req
                          '(:type option :symbol "X" :side short :right put :strike 100 :price 1 :qty 1
                                  :underlying-price 105))
                         :allowed))
  (should-not (plist-get (alpaca-broker-model-test--req
                          '(:type calendar :symbol "X" :right call :long-strike 100 :short-strike 100
                                  :long-price 5 :short-price 3 :long-expires-later t :qty 1))
                         :allowed)))

(alpaca-broker-model-test--deftest alpaca-broker-model-limited-and-ira
  "Below $2,000 equity buying power is cash (1x); limited margin has no short
selling; IRAs allow options up to level 2 only."
  (let ((small (broker-model-account 'alpaca 'margin :cash 1500.0)))
    (should-not (plist-get small :margin-enabled))
    (should (alpaca-broker-model-test--near (plist-get small :stock-bp) 1500.0)))
  (let ((lm (broker-model-account 'alpaca 'limited-margin :cash 5000.0
                                  :positions '((:type stock :symbol "A" :price 10 :qty 100)))))
    (should (alpaca-broker-model-test--near (plist-get lm :stock-bp) 4000.0))
    (should (= 0.0 (plist-get lm :sma))))
  (should-not (plist-get (alpaca-broker-model-test--req '(:type stock :symbol "A" :side short :price 10 :qty 1)
                                                        'limited-margin)
                         :allowed))
  (should-not (plist-get (alpaca-broker-model-test--req
                          '(:type vertical :symbol "A" :right put :long-strike 90 :short-strike 95
                                  :long-price 1 :short-price 2 :qty 1)
                          'ira)
                         :allowed))
  (should (plist-get (alpaca-broker-model-test--req
                      '(:type option :symbol "A" :side long :right call :strike 100 :price 2 :qty 1)
                      'ira)
                     :allowed)))

(alpaca-broker-model-test--deftest alpaca-broker-model-intraday-and-crypto
  "Intraday margin rule (PDT removed, de minimis $1,000 / 5%); crypto 100%."
  (let ((c (broker-model-day-trade-check 'alpaca 'margin :equity 5000.0 :day-trades 20 :deficit 200.0)))
    (should (eq (plist-get c :regime) 'intraday-margin))
    (should (plist-get c :allowed))
    (should-not (plist-get c :call)))
  (should (plist-get (broker-model-day-trade-check 'alpaca 'margin :equity 5000.0 :deficit 300.0) :call))
  (should (alpaca-broker-model-test--near
           (plist-get (alpaca-broker-model-test--req '(:type stock :symbol "BTC/USD" :asset-class crypto
                                                            :price 50000 :qty 1))
                      :initial)
           50000.0)))

(alpaca-broker-model-test--deftest alpaca-broker-model-sources
  "Every Alpaca cell has a source and confidence; every local capture cited exists."
  (let ((dir (file-name-directory (locate-library "alpaca-broker-model"))))
    (dolist (acct '(margin limited-margin ira))
      (dolist (kc (broker-model-resolve 'alpaca acct))
        (let ((src (plist-get (cdr kc) :source)))
          (should (stringp src))
          (should (memq (plist-get (cdr kc) :confidence)
                        '(regulatory official community inferred unpublished)))
          (let ((start 0))
            (while (string-match "\\(docs/margin/[^ ,);]+\\)" src start)
              (should (file-exists-p (expand-file-name (match-string 1 src) dir)))
              (setq start (match-end 0)))))))))

(alpaca-broker-model-test--deftest alpaca-broker-model-cross-broker
  "Same positions at Schwab and Alpaca (needs ../schwab-broker.el)."
  (skip-unless (ignore-errors (require 'schwab-broker-model)))
  (let* ((targets '((schwab . reg-t) (alpaca . margin) (regulatory . reg-t)))
         (row (lambda (rows b) (cl-find b rows :key (lambda (r) (plist-get r :broker)))))
         (naked (broker-model-compare '(:type option :symbol "X" :side short :right put :strike 100 :price 1.0
                                              :qty 1 :underlying-price 110)
                                      targets))
         (cheap (broker-model-compare '(:type stock :symbol "Y" :price 5 :qty 100) targets))
         (spread (broker-model-compare '(:type vertical :symbol "Z" :right put :long-strike 90 :short-strike 95
                                               :long-price 1 :short-price 2 :qty 1)
                                       targets)))
    ;; naked put: Schwab yes (20% formula), Alpaca no (no uncovered level)
    (should (plist-get (funcall row naked 'schwab) :allowed))
    (should-not (plist-get (funcall row naked 'alpaca) :allowed))
    ;; $5 stock: Schwab 25%, Alpaca 50% ($2.50-$6 tier), FINRA 25%
    (should (alpaca-broker-model-test--near (plist-get (funcall row cheap 'schwab) :maintenance) 125.0))
    (should (alpaca-broker-model-test--near (plist-get (funcall row cheap 'alpaca) :maintenance) 250.0))
    (should (alpaca-broker-model-test--near (plist-get (funcall row cheap 'regulatory) :maintenance) 125.0))
    ;; put credit spread: width everywhere, net 400
    (dolist (b '(schwab alpaca regulatory))
      (should (alpaca-broker-model-test--near (plist-get (funcall row spread b) :buying-power-effect) 400.0)))))

(provide 'alpaca-broker-model-test)
;;; alpaca-broker-model-test.el ends here
