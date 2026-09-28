;;; alpaca-broker-live-test.el --- Live ERT suite against Alpaca's paper API -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Live, network-hitting ERT tests against Alpaca's real PAPER trading
;; and market-data APIs.  NOT run in CI, and every test in this file
;; skips itself (via `alpaca-broker-live-test--skip-unless-credentialed')
;; unless `ALPACA_API_PAPER_KEY'/`ALPACA_API_PAPER_SECRET' are set in
;; the environment.  Run locally with:
;;
;;   test/live/run-live-tests.sh
;;
;; which resolves those two env vars via David's credentials resolver
;; (infrastructure/trading/credentials.py in ~/.dotfiles) and exports
;; them only into its own Emacs subprocess -- never printed or logged.
;; Or export them yourself and run:
;;
;;   emacs -Q --batch -L . -L test \
;;     -l test/live/alpaca-broker-live-test.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; Safety:
;; - `alpaca-broker-paper' is forced to t at the top of this file and
;;   never rebound -- nothing here ever touches Alpaca's live trading
;;   endpoints.
;; - `alpaca-broker-allow-orders' stays nil except inside the handful
;;   of tests that deliberately place/replace/cancel a paper order or
;;   mutate a watchlist/position, each of which `let'-binds it locally.
;; - Order-placing tests use a limit price far below market (SPY at
;;   $1.00) so the order can never fill during the test run.
;; - Crypto-wallet withdrawal/whitelist mutation is NEVER exercised
;;   here, even gated -- an on-chain transfer is irreversible in a way
;;   a paper trade or a watchlist edit is not; see the corresponding
;;   `ert-skip' stubs below.
;; - Every test cleans up anything it creates (cancels the order it
;;   placed, deletes the watchlist it created) before returning.

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(add-to-list
 'load-path
 (file-name-directory
  (directory-file-name
   (file-name-directory
    (directory-file-name
     (file-name-directory (or load-file-name buffer-file-name)))))))
(require 'alpaca-broker)
(require 'alpaca-broker-trading)
(require 'alpaca-broker-orders)
(require 'alpaca-broker-watchlists)
(require 'alpaca-broker-wallets)
(require 'alpaca-broker-data-stocks)
(require 'alpaca-broker-data-options)
(require 'alpaca-broker-data-crypto)
(require 'alpaca-broker-data-news)
(require 'alpaca-broker-data-misc)

(setq alpaca-broker-paper t)

(defun alpaca-broker-live-test--credentialed-p ()
  "Return non-nil when both paper credential env vars are set and non-empty."
  (let ((key (getenv "ALPACA_API_PAPER_KEY"))
        (secret (getenv "ALPACA_API_PAPER_SECRET")))
    (and key (not (string-empty-p key))
         secret (not (string-empty-p secret)))))

(defmacro alpaca-broker-live-test--skip-unless-credentialed ()
  "Skip the current test unless paper credentials are in the environment."
  `(skip-unless (alpaca-broker-live-test--credentialed-p)))

(defvar alpaca-broker-live-test--option-symbol nil
  "Memoized real, listed AAPL option contract symbol, or `:none' if
none could be discovered.  Populated on first use by
`alpaca-broker-live-test--option-symbol'.")

(defun alpaca-broker-live-test--option-symbol ()
  "Return a real, currently listed AAPL option contract symbol.
Discovered once via `alpaca-broker-option-contracts-sync' and memoized
in `alpaca-broker-live-test--option-symbol'.  Returns nil if none is
available (e.g. options trading not enabled on this account)."
  (when (null alpaca-broker-live-test--option-symbol)
    (setq alpaca-broker-live-test--option-symbol
          (or (condition-case nil
                  (let* ((page (alpaca-broker-option-contracts-sync
                                '(("underlying_symbols" . "AAPL")
                                  ("status" . "active")
                                  ("limit" . "1"))))
                         (contract (car (alist-get 'option_contracts page))))
                    (and contract (alist-get 'symbol contract)))
                (alpaca-broker-error nil))
              :none)))
  (unless (eq alpaca-broker-live-test--option-symbol :none)
    alpaca-broker-live-test--option-symbol))

;; -- account, configuration, activity, history --

(ert-deftest alpaca-broker-live-account-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alist-get 'id (alpaca-broker-account-sync))))

(ert-deftest alpaca-broker-live-account-configurations-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-account-configurations-sync)))

(ert-deftest alpaca-broker-live-account-activities-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  ;; An empty list is a valid, successful response on a fresh account.
  (should (listp (alpaca-broker-account-activities-sync '(("page_size" . "5"))))))

(ert-deftest alpaca-broker-live-account-activities-by-type-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (listp (alpaca-broker-account-activities-by-type-sync "FILL"))))

(ert-deftest alpaca-broker-live-portfolio-history-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-portfolio-history-sync '(("period" . "1M")))))

;; -- assets, option contracts, corporate actions, calendar, clock --

(ert-deftest alpaca-broker-live-assets-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (> (length (alpaca-broker-assets-sync '(("status" . "active")))) 0)))

(ert-deftest alpaca-broker-live-asset-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (equal (alist-get 'symbol (alpaca-broker-asset-sync "AAPL")) "AAPL")))

(ert-deftest alpaca-broker-live-option-contracts-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-option-contracts-sync '(("underlying_symbols" . "AAPL")
                                                  ("limit" . "5")))))

(ert-deftest alpaca-broker-live-option-contract-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((symbol (alpaca-broker-live-test--option-symbol)))
    (if (null symbol)
        (ert-skip "no active AAPL option contract discovered")
      (should (equal (alist-get 'symbol (alpaca-broker-option-contract-sync symbol))
                      symbol)))))

(ert-deftest alpaca-broker-live-corporate-action-announcements-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (listp (alpaca-broker-corporate-action-announcements-sync
                  "Dividend" "2024-01-01" "2024-02-01"))))

(ert-deftest alpaca-broker-live-corporate-actions-sync ()
  "Market-data flavor (`/v1/corporate-actions')."
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-corporate-actions-sync
           '(("symbols" . "AAPL") ("start" . "2024-01-01") ("end" . "2024-02-01")))))

(ert-deftest alpaca-broker-live-calendar-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (> (length (alpaca-broker-calendar-sync '(("start" . "2024-01-01")
                                                     ("end" . "2024-01-10"))))
             0)))

(ert-deftest alpaca-broker-live-clock-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (memq (alist-get 'is_open (alpaca-broker-clock-sync)) '(t :false))))

;; -- crypto funding wallets (reads only) --

(ert-deftest alpaca-broker-live-wallets-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-wallets-sync)))

(ert-deftest alpaca-broker-live-wallet-fee-estimate-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-wallet-fee-estimate-sync '(("asset" . "BTC")))))

(ert-deftest alpaca-broker-live-wallet-transfers-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (listp (alpaca-broker-wallet-transfers-sync))))

(ert-deftest alpaca-broker-live-wallet-vasps-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-wallet-vasps-sync)))

(ert-deftest alpaca-broker-live-wallet-whitelist-addresses-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (listp (alpaca-broker-wallet-whitelist-addresses-sync))))

(ert-deftest alpaca-broker-live-wallet-transfer-sync ()
  "Needs an existing transfer id -- skipped when there is none."
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((transfer (car (alpaca-broker-wallet-transfers-sync))))
    (if (null transfer)
        (ert-skip "no existing wallet transfer to fetch")
      (should (alpaca-broker-wallet-transfer-sync (alist-get 'id transfer))))))

;; -- crypto funding wallets (mutations): deliberately never live-tested --

(ert-deftest alpaca-broker-live-create-wallet-transfer-sync ()
  (ert-skip "not live-tested by design: an on-chain crypto withdrawal is irreversible"))

(ert-deftest alpaca-broker-live-create-wallet-whitelist-address-sync ()
  (ert-skip "not live-tested by design: pairs with the withdrawal transfer above"))

(ert-deftest alpaca-broker-live-delete-wallet-whitelist-address-sync ()
  (ert-skip "not live-tested by design: nothing was ever created to delete"))

(ert-deftest alpaca-broker-live-update-wallet-whitelist-travel-rule-info-sync ()
  (ert-skip "not live-tested by design: nothing was ever created to update"))

;; -- orders: full create/get/replace/cancel flow --

(ert-deftest alpaca-broker-live-orders-flow ()
  "Place a limit order for 1 share of SPY at $1.00 (far below market, so
it can never fill during this test), fetch it by id and by client
order id, replace its limit price, then cancel it."
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let* ((alpaca-broker-allow-orders t)
         (client-id (format "alpaca-broker-el-test-%d" (float-time)))
         (created (alpaca-broker-create-order-sync
                   `(("symbol" . "SPY") ("qty" . "1") ("side" . "buy")
                     ("type" . "limit") ("time_in_force" . "day")
                     ("limit_price" . "1.00")
                     ("client_order_id" . ,client-id))))
         (order-id (alist-get 'id created)))
    (unwind-protect
        (progn
          (should order-id)
          (should (equal (alist-get 'id (alpaca-broker-order-sync order-id))
                          order-id))
          (should (equal (alist-get 'client_order_id
                                     (alpaca-broker-order-by-client-id-sync client-id))
                          client-id))
          (let ((replaced (alpaca-broker-replace-order-sync
                            order-id '(("limit_price" . "1.01")))))
            (should (alist-get 'id replaced))
            (setq order-id (alist-get 'id replaced))))
      (when order-id
        (ignore-errors (alpaca-broker-cancel-order-sync order-id))))))

(ert-deftest alpaca-broker-live-orders-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (listp (alpaca-broker-orders-sync '(("status" . "all") ("limit" . "5"))))))

(ert-deftest alpaca-broker-live-cancel-all-orders-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((alpaca-broker-allow-orders t))
    (should (listp (alpaca-broker-cancel-all-orders-sync)))))

;; -- positions --

(ert-deftest alpaca-broker-live-positions-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (listp (alpaca-broker-positions-sync))))

(ert-deftest alpaca-broker-live-position-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((position (car (alpaca-broker-positions-sync))))
    (if (null position)
        (ert-skip "no position")
      (should (alist-get 'symbol
                          (alpaca-broker-position-sync
                           (alist-get 'symbol position)))))))

(ert-deftest alpaca-broker-live-close-position-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((position (car (alpaca-broker-positions-sync))))
    (if (null position)
        (ert-skip "no position")
      (let ((alpaca-broker-allow-orders t))
        (should (alpaca-broker-close-position-sync (alist-get 'symbol position)))))))

(ert-deftest alpaca-broker-live-close-all-positions-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (if (null (alpaca-broker-positions-sync))
      (ert-skip "no position")
    (let ((alpaca-broker-allow-orders t))
      (should (listp (alpaca-broker-close-all-positions-sync))))))

;; -- options exercise: skipped unless a held option position exists --

(ert-deftest alpaca-broker-live-exercise-position-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((position (car (alpaca-broker-positions-sync))))
    (if (or (null position) (not (equal (alist-get 'asset_class position) "us_option")))
        (ert-skip "no held option position")
      (let ((alpaca-broker-allow-orders t))
        (should (alpaca-broker-exercise-position-sync (alist-get 'symbol position)))))))

(ert-deftest alpaca-broker-live-decline-exercise-position-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((position (car (alpaca-broker-positions-sync))))
    (if (or (null position) (not (equal (alist-get 'asset_class position) "us_option")))
        (ert-skip "no held option position")
      (let ((alpaca-broker-allow-orders t))
        (should (alpaca-broker-decline-exercise-position-sync
                 (alist-get 'symbol position)))))))

;; -- watchlists: full CRUD flow, both by id and by name --

(ert-deftest alpaca-broker-live-watchlists-flow ()
  "Create a watchlist, exercise every by-id and by-name CRUD op on it,
then delete it."
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let* ((name (format "alpaca-broker-el-test-%d" (float-time)))
         (watchlist (alpaca-broker-create-watchlist-sync name '("AAPL")))
         (id (alist-get 'id watchlist)))
    (unwind-protect
        (progn
          (should id)
          (should (equal (alist-get 'id (alpaca-broker-watchlist-sync id)) id))
          (should (alpaca-broker-update-watchlist-sync id `(("name" . ,name))))
          (should (alpaca-broker-add-watchlist-asset-sync id "MSFT"))
          (should (alpaca-broker-remove-watchlist-asset-sync id "MSFT"))
          (should (equal (alist-get 'id (alpaca-broker-watchlist-by-name-sync name)) id))
          (should (alpaca-broker-update-watchlist-by-name-sync name `(("name" . ,name))))
          (should (alpaca-broker-add-watchlist-asset-by-name-sync name "MSFT"))
          (should (member id (mapcar (lambda (w) (alist-get 'id w))
                                      (alpaca-broker-watchlists-sync)))))
      (when id
        (ignore-errors (alpaca-broker-delete-watchlist-by-name-sync name))))))

;; -- market data: stocks --

(ert-deftest alpaca-broker-live-bars-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-bars-sync "AAPL" "1Day" nil nil 5)))

(ert-deftest alpaca-broker-live-stocks-bars-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-bars-sync '("AAPL" "MSFT") "1Day" '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-latest-bar-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-latest-bar-sync "AAPL")))

(ert-deftest alpaca-broker-live-stocks-latest-bars-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-latest-bars-sync '("AAPL"))))

(ert-deftest alpaca-broker-live-trades-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-trades-sync "AAPL" '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-stocks-trades-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-trades-sync '("AAPL") '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-latest-trade-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-latest-trade-sync "AAPL")))

(ert-deftest alpaca-broker-live-stocks-latest-trades-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-latest-trades-sync '("AAPL"))))

(ert-deftest alpaca-broker-live-latest-quote-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-latest-quote-sync "AAPL")))

(ert-deftest alpaca-broker-live-quotes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-quotes-sync "AAPL" '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-stocks-quotes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-quotes-sync '("AAPL") '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-stocks-latest-quotes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-latest-quotes-sync '("AAPL"))))

(ert-deftest alpaca-broker-live-snapshot-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-snapshot-sync "AAPL")))

(ert-deftest alpaca-broker-live-stocks-snapshots-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-snapshots-sync '("AAPL"))))

(ert-deftest alpaca-broker-live-auctions-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-auctions-sync "AAPL" '(("start" . "2024-01-02")
                                                 ("end" . "2024-01-05")))))

(ert-deftest alpaca-broker-live-stocks-auctions-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-auctions-sync
           '("AAPL") '(("start" . "2024-01-02") ("end" . "2024-01-05")))))

(ert-deftest alpaca-broker-live-stocks-condition-codes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-condition-codes-sync "trade" "A")))

(ert-deftest alpaca-broker-live-stocks-exchange-codes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-stocks-exchange-codes-sync)))

;; -- market data: options --

(ert-deftest alpaca-broker-live-options-bars-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((symbol (alpaca-broker-live-test--option-symbol)))
    (if (null symbol)
        (ert-skip "no active AAPL option contract discovered")
      (should (alpaca-broker-options-bars-sync symbol "1Day" '(("limit" . "5")))))))

(ert-deftest alpaca-broker-live-options-trades-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((symbol (alpaca-broker-live-test--option-symbol)))
    (if (null symbol)
        (ert-skip "no active AAPL option contract discovered")
      (should (alpaca-broker-options-trades-sync symbol '(("limit" . "5")))))))

(ert-deftest alpaca-broker-live-options-latest-trades-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((symbol (alpaca-broker-live-test--option-symbol)))
    (if (null symbol)
        (ert-skip "no active AAPL option contract discovered")
      (should (alpaca-broker-options-latest-trades-sync symbol)))))

(ert-deftest alpaca-broker-live-options-latest-quotes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((symbol (alpaca-broker-live-test--option-symbol)))
    (if (null symbol)
        (ert-skip "no active AAPL option contract discovered")
      (should (alpaca-broker-options-latest-quotes-sync symbol)))))

(ert-deftest alpaca-broker-live-options-snapshots-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (let ((symbol (alpaca-broker-live-test--option-symbol)))
    (if (null symbol)
        (ert-skip "no active AAPL option contract discovered")
      (should (alpaca-broker-options-snapshots-sync symbol)))))

(ert-deftest alpaca-broker-live-options-chain-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-options-chain-sync "AAPL" '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-options-condition-codes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-options-condition-codes-sync "trade")))

(ert-deftest alpaca-broker-live-options-exchange-codes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-options-exchange-codes-sync)))

;; -- market data: crypto --

(ert-deftest alpaca-broker-live-crypto-bars-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-bars-sync "BTC/USD" "1Day" nil nil 5)))

(ert-deftest alpaca-broker-live-crypto-bars-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-bars-multi-sync
           '("BTC/USD" "ETH/USD") "1Day" '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-crypto-latest-bars-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-latest-bars-multi-sync '("BTC/USD"))))

(ert-deftest alpaca-broker-live-crypto-trades-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-trades-multi-sync '("BTC/USD") '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-crypto-latest-trade-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-latest-trade-sync "BTC/USD")))

(ert-deftest alpaca-broker-live-crypto-latest-trades-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-latest-trades-multi-sync '("BTC/USD"))))

(ert-deftest alpaca-broker-live-crypto-latest-quote-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-latest-quote-sync "BTC/USD")))

(ert-deftest alpaca-broker-live-crypto-quotes-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-quotes-multi-sync '("BTC/USD") '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-crypto-latest-quotes-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-latest-quotes-multi-sync '("BTC/USD"))))

(ert-deftest alpaca-broker-live-crypto-latest-orderbooks-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-latest-orderbooks-multi-sync '("BTC/USD"))))

(ert-deftest alpaca-broker-live-crypto-snapshots-multi-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-crypto-snapshots-multi-sync '("BTC/USD"))))

;; -- market data: forex, fixed income, news, screener, logos --

(ert-deftest alpaca-broker-live-forex-rates-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-forex-rates-sync "EUR/USD" '(("limit" . "5")))))

(ert-deftest alpaca-broker-live-forex-latest-rates-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-forex-latest-rates-sync "EUR/USD")))

(ert-deftest alpaca-broker-live-fixed-income-latest-prices-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-fixed-income-latest-prices-sync "US912810TW82")))

(ert-deftest alpaca-broker-live-fixed-income-latest-quotes-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-fixed-income-latest-quotes-sync "US912810TW82")))

(ert-deftest alpaca-broker-live-news-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-news-sync '(("symbols" . "AAPL") ("limit" . "5")))))

(ert-deftest alpaca-broker-live-screener-most-actives-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-screener-most-actives-sync '(("top" . "5")))))

(ert-deftest alpaca-broker-live-screener-movers-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-screener-movers-sync "stocks" '(("top" . "5")))))

(ert-deftest alpaca-broker-live-logo-sync ()
  (alpaca-broker-live-test--skip-unless-credentialed)
  (should (alpaca-broker-logo-sync "AAPL")))

(provide 'alpaca-broker-live-test)
;;; alpaca-broker-live-test.el ends here
