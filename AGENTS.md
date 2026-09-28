# AGENTS.md — alpaca-broker.el

Standalone, publishable Emacs package: pure-elisp Alpaca API client with
full coverage of Alpaca's Trading API and Market Data API (paper and
live). Built url.el-only with zero external elisp dependencies;
credentials resolve defcustom → auth-source → env
(`ALPACA_API_PAPER_KEY`/`_SECRET` when `alpaca-broker-paper` is
non-nil, else the live pair).

## For agents and contributors

- Read `README.md` first; it is the complete function reference, and
  `ROADMAP.md` for the full endpoint coverage matrix (one row per
  Alpaca endpoint: elisp function, mocked-test status, live-test
  status).
- Tests, two kinds:
  - Mocked ERT in `test/alpaca-broker-*-test.el` (one file per source
    file), HTTP mocked at the `url-retrieve` boundary — run offline,
    no credentials needed. Run them with:

    ```sh
    emacs -Q --batch -L . -L test $(printf ' -l %s' test/*.el) \
      -f ert-run-tests-batch-and-exit
    ```
  - Live ERT in `test/live/alpaca-broker-live-test.el`, hitting
    Alpaca's real paper API. Never run in CI; skips itself unless
    `ALPACA_API_PAPER_KEY`/`ALPACA_API_PAPER_SECRET` are set. Run with
    `test/live/run-live-tests.sh`, which resolves those two env vars
    via David's credentials resolver and exports them only into its
    own Emacs subprocess.
- Zero external Elisp dependencies. HTTP goes through the built-in
  `url.el`, JSON is parsed with the built-in `json-parse-buffer`.
- Order safety is gated, not absent: every function that places,
  replaces, or cancels an order, closes a position, or
  exercises/declines an option contract calls
  `alpaca-broker--require-order-permission` first, which signals a
  `user-error` unless the defcustom `alpaca-broker-allow-orders` is
  non-nil. It defaults to nil, so no order-mutating request can ever
  fire by accident; a caller must explicitly opt in (and should keep
  `alpaca-broker-paper' non-nil, its own default, while doing so). See
  ROADMAP.md for the full endpoint coverage matrix.
