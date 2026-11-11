;;; alpaca-broker-model.el --- Alpaca account rules for broker-model -*- lexical-binding: t; -*-

;; Author: David Awad <me@davidaw.ad>
;; Maintainer: David Awad <me@davidaw.ad>
;; Package-Requires: ((emacs "27.1") (broker-model "0.1.0"))
;; Keywords: comm, tools, finance

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT
;; MIT License; see LICENSE in this package's directory for the full text.

;;; Commentary:

;; Registers Alpaca Securities with broker-model (the sibling package
;; broker-model.el): account types margin (Reg T, the default once
;; equity is $2,000+), limited-margin (1x buying power) and ira (Broker
;; API IRAs: 1x, options up to level 2).  Every rule cell cites the
;; Alpaca doc it comes from; captures with URL and fetch date are in
;; docs/margin/.  Values Alpaca does not publish are marked
;; `unpublished'.
;;
;; Alpaca has no portfolio-margin account and no uncovered options:
;; options level 3 is defined-risk spreads only.  Option spreads use
;; Alpaca's "universal spread rule" (maximum loss from intrinsic
;; values, per expiration), so calendars whose short leg stands alone
;; in its expiry are uncovered and not permitted.
;;
;; This is the only file in alpaca-broker.el that depends on
;; broker-model; nothing else requires it.

;;; Code:

(require 'broker-model)

(defconst alpaca-broker-model--margin
  "Alpaca: Margin and Short Selling https://docs.alpaca.markets/docs/margin-and-short-selling (docs/margin/margin-and-short-selling.md, fetched 2026-11-10)"
  "Alpaca margin doc.")
(defconst alpaca-broker-model--account
  "Alpaca: Trading Account https://docs.alpaca.markets/docs/account-plans (docs/margin/trading-account.md)"
  "Alpaca account doc.")
(defconst alpaca-broker-model--options
  "Alpaca: Options Trading https://docs.alpaca.markets/docs/options-trading (docs/margin/options-trading.md)"
  "Alpaca options doc.")
(defconst alpaca-broker-model--options-bp
  "Alpaca: Options Trading Overview (Broker API) https://docs.alpaca.markets/us/docs/options-trading-overview (docs/margin/options-trading-overview-broker-api.md), Buying Power Checks"
  "Alpaca options buying power checks.")
(defconst alpaca-broker-model--l3
  "Alpaca: Options Level 3 Trading https://docs.alpaca.markets/docs/options-level-3-trading (docs/margin/options-level-3-trading.md)"
  "Alpaca level 3 doc.")
(defconst alpaca-broker-model--intraday
  "Alpaca: The Intraday Margin Rule https://docs.alpaca.markets/us/docs/the-intraday-margin-rule (docs/margin/intraday-margin-rule.md)"
  "Alpaca intraday margin doc.")
(defconst alpaca-broker-model--ira
  "Alpaca: IRA Accounts Overview (Broker API) https://docs.alpaca.markets/us/docs/ira-accounts-overview (docs/margin/ira-accounts-overview-broker-api.md)"
  "Alpaca IRA doc.")
(defconst alpaca-broker-model--protect
  "Alpaca: User Protection https://docs.alpaca.markets/docs/user-protection (docs/margin/user-protection.md)"
  "Alpaca user protection doc.")
(defconst alpaca-broker-model--nonlev
  "Alpaca: Intraday Margin Rule for Non-Leverage Margin Accounts https://docs.alpaca.markets/us/docs/understanding-the-new-intraday-margin-rule (docs/margin/intraday-margin-rule-non-leverage.md)"
  "Alpaca non-leverage margin doc.")

(defun alpaca-broker-model--c (v s c &optional n)
  "Shorthand rule cell: value V, source S, confidence C, note N."
  (broker-model-cell v s c n))

(defconst alpaca-broker-model-option-levels
  '((:level 0 :name "Disabled" :adds ())
    (:level 1 :name "Level 1" :adds (covered-call cash-secured-put))
    (:level 2 :name "Level 2" :adds (long-option straddle-long strangle-long))
    (:level 3 :name "Level 3" :adds (vertical-debit vertical-credit spread iron-condor)))
  "Alpaca options trading levels (each adds to the levels below).")

(defconst alpaca-broker-model-rules
  (list
   :min-equity-margin (alpaca-broker-model--c 2000.0 (concat alpaca-broker-model--margin ": margin and short selling need $2,000 equity; below that 1x buying power") 'official)
   :long-stock (alpaca-broker-model--c '((:min-price 6.0 :initial 0.50 :maintenance 0.30)
                                         (:min-price 2.5 :initial 0.50 :maintenance 0.50)
                                         (:min-price 0.0 :initial 0.50 :maintenance 1.00))
                                       (concat alpaca-broker-model--margin " (overnight maintenance table: > $6 30%, $2.50-$6 50%, < $2.50 100%; 50% initial)") 'official
                                       "Alpaca writes '> $6.00' for 30%; the model applies 30% at exactly $6.00.  Whether sub-$2.50 shares are marginable for initial margin is not stated")
   :short-stock (alpaca-broker-model--c '(:initial 0.50
                                          :tiers ((:min-price 5.0 :pct 0.30 :per-share 5.0)
                                                  (:min-price 0.0 :pct 1.00 :per-share 2.50)))
                                        (concat alpaca-broker-model--margin " (short: < $5 greater of $2.50/share or 100%; >= $5 greater of $5/share or 30%)") 'official
                                        "hard-to-borrow names need a locate first")
   :leveraged-etf-long (alpaca-broker-model--c '(:initial 0.50 :maintenance-per-x 0.25 :cap 1.0)
                                               (concat alpaca-broker-model--margin " (2x leveraged ETF 50%, 3x 75% of EOD market value)") 'official)
   :concentration (alpaca-broker-model--c '(:share 0.70 :min-debit 100000.0 :maintenance 0.50)
                                          (concat alpaca-broker-model--margin " (Concentrated Margin Requirements: one security >= 70% of equities' market value and margin balance >= $100,000 -> 50%)") 'official)
   :crypto-marginable (alpaca-broker-model--c nil (concat alpaca-broker-model--account " (crypto is not margin collateral; cash only)") 'official)
   :long-option (alpaca-broker-model--c '(:pct 1.0 :leaps-pct 1.0 :leaps-months 9)
                                        (concat alpaca-broker-model--options-bp " (buying a call or put needs options buying power for the premium)") 'official)
   :covered-call (alpaca-broker-model--c 0.0 (concat alpaca-broker-model--options-bp " (covered call needs the shares)") 'official)
   :csp-reserve (alpaca-broker-model--c '(:net-of-premium t)
                                        (concat alpaca-broker-model--options-bp " (cash-secured put: buying power for the underlying minus the premium; error example 'required: 20310')") 'official)
   :csp-collateral (alpaca-broker-model--c '(options-buying-power) alpaca-broker-model--options-bp 'official)
   :spread-rule (alpaca-broker-model--c 'universal-max-loss-per-expiry
                                        (concat alpaca-broker-model--l3 " (maintenance = worst intrinsic payoff over all legs, premiums ignored, per expiration, largest used; cost basis = maintenance + net price)") 'official)
   :calendar-rule (alpaca-broker-model--c 'per-expiration-max-loss
                                          (concat alpaca-broker-model--l3 " (per-expiration max loss; MLeg orders with uncovered legs rejected, which 'impacts ... rolling a calendar spread')") 'official
                                          "a calendar's short leg is uncovered in its own expiry, so calendars are not modeled as permitted")
   :bp-overnight-multiplier (alpaca-broker-model--c 2.0 (concat alpaca-broker-model--account " (multiplier 2: buying_power = max(equity - initial_margin, 0) x 2)") 'official)
   :bp-intraday-multiplier (alpaca-broker-model--c 4.0 (concat alpaca-broker-model--account " (multiplier 4: (last_equity - last_maintenance_margin) x 4)") 'official)
   :bp-intraday-basis (alpaca-broker-model--c 'previous-close-maintenance-excess alpaca-broker-model--account 'official)
   :bp-option-basis (alpaca-broker-model--c 'sma-less-reserves alpaca-broker-model--options-bp 'unpublished
                                            "options_buying_power exists but its formula is not published; modeled as equity - initial - reserves")
   :intraday (alpaca-broker-model--c '(:regime intraday-margin :de-minimis-dollars 1000 :de-minimis-pct 0.05
                                       :cure-business-days 2 :freeze-after-business-days 5 :freeze-days 90)
                                     (concat alpaca-broker-model--intraday "; " alpaca-broker-model--nonlev " (PDT designation removed; no $25,000 minimum; deficit call due in 2 business days; 90-day freeze after the 5th)") 'official)
   :equity-order-ratio-cap (alpaca-broker-model--c 6.0 (concat alpaca-broker-model--protect " (a position 600% of equity restricts the account to closing transactions)") 'official
                                                   "a review trigger, not a margin requirement; not computed")
   :option-levels (alpaca-broker-model--c alpaca-broker-model-option-levels (concat alpaca-broker-model--options " (Trading Levels 0-3)") 'official
                                          "no uncovered (naked) option level is offered")
   :permitted (alpaca-broker-model--c '(long-stock short-stock long-option covered-call cash-secured-put
                                        vertical-debit vertical-credit spread iron-condor
                                        straddle-long strangle-long)
                                      (concat alpaca-broker-model--options " (levels 1-3); " alpaca-broker-model--margin " (short selling)") 'official
                                      "naked options, short straddles/strangles, calendars, protective puts and collars as combo orders are not offered (MLeg orders cannot include an equity leg)"))
  "Alpaca broker-wide rule cells.")

(defconst alpaca-broker-model-limited-rules
  (list
   :settled-only (alpaca-broker-model--c nil (concat alpaca-broker-model--nonlev " (margin-enabled accounts avoid T+1 settlement delays)") 'official)
   :spread-collateral (alpaca-broker-model--c 'max-loss alpaca-broker-model--l3 'inferred
                                              "Alpaca does not say whether level 3 applies to 1x accounts")
   :permitted (alpaca-broker-model--c '(long-stock long-option covered-call cash-secured-put
                                        vertical-debit vertical-credit spread iron-condor
                                        straddle-long strangle-long)
                                      (concat alpaca-broker-model--margin " (below $2,000: no margin, no short selling, 1x)") 'inferred
                                      "options levels for 1x accounts are not stated separately"))
  "Alpaca limited-margin (1x) account-type rule cells.")

(defconst alpaca-broker-model-ira-rules
  (list
   :settled-only (alpaca-broker-model--c nil (concat alpaca-broker-model--ira " (IRAs are limited margin, 1x)") 'official)
   :permitted (alpaca-broker-model--c '(long-stock long-option covered-call cash-secured-put straddle-long strangle-long)
                                      (concat alpaca-broker-model--ira " (options up to level 2; no crypto)") 'official
                                      "Broker API product; the Trading API does not offer retirement accounts"))
  "Alpaca IRA account-type rule cells.")

;;;###autoload
(defun alpaca-broker-model-register ()
  "Register Alpaca and its account types with broker-model."
  (broker-model-define-broker 'alpaca :name "Alpaca Securities" :url "https://docs.alpaca.markets/docs/margin-and-short-selling"
                              :rules alpaca-broker-model-rules)
  (broker-model-define-account-type 'alpaca 'margin :name "Margin (Reg T, 2x/4x)" :baseline 'reg-t)
  (broker-model-define-account-type 'alpaca 'limited-margin :name "Limited margin (1x)" :baseline 'cash
                                    :rules alpaca-broker-model-limited-rules)
  (broker-model-define-account-type 'alpaca 'ira :name "IRA (Broker API, 1x)" :baseline 'cash
                                    :rules alpaca-broker-model-ira-rules)
  'alpaca)

;;;###autoload
(defun alpaca-broker-model-required-level (strategy-class)
  "Lowest Alpaca options level that permits STRATEGY-CLASS, or nil."
  (let (level)
    (dolist (l alpaca-broker-model-option-levels)
      (when (and (null level) (memq strategy-class (plist-get l :adds)))
        (setq level (plist-get l :level))))
    level))

(alpaca-broker-model-register)

(provide 'alpaca-broker-model)
;;; alpaca-broker-model.el ends here
