# AGENTS.md — alpaca-broker.el

Standalone, publishable Emacs package: pure-elisp Alpaca API client
(market data + read-only account/positions, paper and live). Built
url.el-only with zero external elisp dependencies; credentials resolve
defcustom → auth-source → env (`ALPACA_API_PAPER_KEY`/`_SECRET` when
`alpaca-broker-paper` is non-nil, else the live pair).

## For agents and contributors

- Read `README.md` first; it is the complete function reference.
- Tests: ERT in `test/alpaca-broker-test.el`, HTTP mocked at the
  url-retrieve boundary — they run offline, no credentials needed. Run
  them with:

  ```sh
  emacs -Q --batch -L . -L test -l test/alpaca-broker-test.el \
    -f ert-run-tests-batch-and-exit
  ```
- Zero external Elisp dependencies. HTTP goes through the built-in
  `url.el`, JSON is parsed with the built-in `json-parse-buffer`.
- This package is READ-ONLY by design in v1: no order placement exists.
  Do not add order submission, replacement, or cancellation without the
  maintainer's explicit direction.
