;;; alpaca-broker-orders-test.el --- Tests for alpaca-broker-orders.el -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Mocked ERT tests for `alpaca-broker-orders.el': orders (list, get,
;; get-by-client-id, create, replace, cancel, cancel-all), positions
;; (list, get, close, close-all), and exercise/decline-exercise.  Each
;; test asserts the HTTP method, path, query params, and (where
;; applicable) request body of one endpoint.  Order-mutating and
;; position-closing/exercise functions are additionally asserted to
;; signal a `user-error' when `alpaca-broker-allow-orders' is nil, and
;; to only issue the request once it is non-nil.  Mocks at the
;; `url-retrieve-synchronously' boundary; never makes a real network
;; call.

;;; Code:

(require 'alpaca-broker-test-helpers)
(require 'alpaca-broker-orders)

(defconst alpaca-broker-orders-test--paper "https://paper-api.alpaca.markets")

;; -- orders: read --

(ert-deftest alpaca-broker-orders-test-orders-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-orders-sync '(("status" . "all"))))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/orders?status=all"))))))

(ert-deftest alpaca-broker-orders-test-order-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-order-sync "order-1"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/orders/order-1"))))))

(ert-deftest alpaca-broker-orders-test-order-by-client-id-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-order-by-client-id-sync "client-1"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/orders:by_client_order_id"
                              "?client_order_id=client-1"))))))

;; -- orders: mutate (gated) --

(ert-deftest alpaca-broker-orders-test-create-order-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-create-order-sync '(("symbol" . "SPY")))
                  :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-create-order-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-create-order-sync
                  '(("symbol" . "SPY") ("qty" . "1") ("side" . "buy")
                    ("type" . "limit") ("time_in_force" . "day")
                    ("limit_price" . "1.00"))))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper "/v2/orders")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((symbol . "SPY") (qty . "1") (side . "buy")
                        (type . "limit") (time_in_force . "day")
                        (limit_price . "1.00")))))))

(ert-deftest alpaca-broker-orders-test-replace-order-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-replace-order-sync "order-1" '(("qty" . "2")))
                  :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-replace-order-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-replace-order-sync "order-1" '(("qty" . "2"))))))
      (should (equal (plist-get req :method) "PATCH"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/orders/order-1")))
      (should (equal (alpaca-broker-test--decode-body (plist-get req :data))
                      '((qty . "2")))))))

(ert-deftest alpaca-broker-orders-test-cancel-order-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-cancel-order-sync "order-1")
                  :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-cancel-order-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-cancel-order-sync "order-1"))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/orders/order-1"))))))

(ert-deftest alpaca-broker-orders-test-cancel-all-orders-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-cancel-all-orders-sync) :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-cancel-all-orders-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-cancel-all-orders-sync))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper "/v2/orders"))))))

;; -- positions: read --

(ert-deftest alpaca-broker-orders-test-positions-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-positions-sync))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper "/v2/positions"))))))

(ert-deftest alpaca-broker-orders-test-position-sync ()
  (let ((alpaca-broker-paper t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-position-sync "AAPL"))))
      (should (equal (plist-get req :method) "GET"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/positions/AAPL"))))))

;; -- positions: mutate (gated) --

(ert-deftest alpaca-broker-orders-test-close-position-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-close-position-sync "AAPL") :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-close-position-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-close-position-sync
                  "AAPL" '(("qty" . "1"))))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/positions/AAPL?qty=1"))))))

(ert-deftest alpaca-broker-orders-test-close-all-positions-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-close-all-positions-sync) :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-close-all-positions-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-close-all-positions-sync
                  '(("cancel_orders" . "true"))))))
      (should (equal (plist-get req :method) "DELETE"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/positions?cancel_orders=true"))))))

;; -- options exercise (gated) --

(ert-deftest alpaca-broker-orders-test-exercise-position-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error (alpaca-broker-exercise-position-sync "AAPL240101C00100000")
                  :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-exercise-position-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-exercise-position-sync "AAPL240101C00100000"))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/positions/AAPL240101C00100000/exercise"))))))

(ert-deftest alpaca-broker-orders-test-decline-exercise-position-sync-errors-when-disallowed ()
  (let ((alpaca-broker-allow-orders nil))
    (should-error
     (alpaca-broker-decline-exercise-position-sync "AAPL240101C00100000")
     :type 'user-error)))

(ert-deftest alpaca-broker-orders-test-decline-exercise-position-sync ()
  (let ((alpaca-broker-paper t) (alpaca-broker-allow-orders t))
    (let ((req (alpaca-broker-test--capture-request
                 (alpaca-broker-decline-exercise-position-sync
                  "AAPL240101C00100000"))))
      (should (equal (plist-get req :method) "POST"))
      (should (equal (plist-get req :url)
                      (concat alpaca-broker-orders-test--paper
                              "/v2/positions/AAPL240101C00100000/do-not-exercise"))))))

(provide 'alpaca-broker-orders-test)
;;; alpaca-broker-orders-test.el ends here
