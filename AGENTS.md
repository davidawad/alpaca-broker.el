# AGENTS.md — alpaca-broker.el

Standalone, publishable Emacs package: pure-elisp Alpaca API client
(market data + read-only account/positions, paper and live). Built
url.el-only with zero external elisp dependencies; credentials resolve
defcustom → auth-source → env (`ALPACA_API_PAPER_KEY`/`_SECRET` when
`alpaca-broker-paper` is non-nil, else the live pair).

## For agents

- Read `README.md` first; it is the complete function reference.
- Tests: ERT in `test/alpaca-broker-test.el`, HTTP mocked at the
  url-retrieve boundary — they run offline, no credentials needed.
- This package is READ-ONLY by design in v1: no order placement exists.
  Do not add order submission without the owner's explicit direction.
- Zero references to the owner's dotfiles are allowed here — the repo
  must remain publishable as-is. THIS repo is canonical; the owner's
  dotfiles emacs config imports it via load-path and carries no copy of
  the source. All changes land here.
- Authorized: david, swe.
