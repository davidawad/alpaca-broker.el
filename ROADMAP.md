# ROADMAP.md — alpaca-broker.el coverage matrix

Scope: every endpoint in Alpaca's **Trading API** and **Market Data API**, per
[docs.alpaca.markets/reference](https://docs.alpaca.markets/reference) and
Alpaca's own OpenAPI specs (fetched live 2026-09-28; the public
`alpacahq/alpaca-docs` GitHub mirror is stale since 2022 and was **not** used
as ground truth). Out of scope, deliberately: the **Broker API** (account
opening, funding, journals, ACATS, KYC), **streaming/WebSocket/SSE**
endpoints, Alpaca's **Tokenization** endpoints (`/v2/tokenization/*`) and
**Locates** API (`/v1/locates/*`, explicitly unsupported in paper trading),
and the newer **v3 multi-market calendar/clock** (`/v3/calendar/{market}`,
`/v3/clock`) — the task named the v2 single-market forms specifically.

Every in-scope endpoint has a row below, even where a column reads
"unimplemented" — the goal is that no row stays that way.

Live-tested column key: **pass** (network call succeeded against the paper
account), **fail** (call made it to Alpaca and got an unexpected error),
**skipped: `<reason>`** (a live precondition wasn't met — no open position, no
existing transfer, deliberately not exercised), **blocked (tier)** (Alpaca
itself rejected the request for account-tier/subscription reasons — the
exact HTTP status/error is recorded), or **blocked: `<reason>`** (something
outside Alpaca's control, e.g. credentials, stopped the test from running at
all).

## Status as of 2026-09-28

**All 91 endpoints below are implemented, with a mocked ERT test each (163
mocked tests total, all passing) verifying method/path/params/body shape.**
Live testing against the paper account is **blocked**: the credentials
resolved via `infrastructure/trading/credentials.py`
(`ALPACA_API_PAPER_KEY`/`ALPACA_API_PAPER_SECRET`, sourced from
`~/.config/tradeboards/credentials.env` since the vault has nothing routed
for these keys) are rejected by Alpaca itself with a genuine `401
{"message": "unauthorized."}` on a plain `GET /v2/account` — confirmed
three independent ways: directly with curl, via the already-existing,
independently-tested `infrastructure/trading/providers/alpaca.py`, and by
actually running this package's own live-test harness end to end (some
calls surfaced as `alpaca-broker-error` "request failed or timed out"
rather than a clean 401 -- `url.el` in batch mode can hang/EOF-crash trying
to interactively re-prompt for Basic-auth credentials on a 401 challenge;
that is a `url.el` quirk triggered by the bad credentials, not a defect in
this package's request layer, which already has dedicated mocked coverage
for clean 401/500 signaling). This is not a sandbox/network issue (direct
TLS to Alpaca's real IP; `api.github.com` works fine from the same shell)
— the paper API key pair itself appears stale or revoked. Every row's
"live-tested" column below reads **blocked: invalid paper credentials
(401)** pending David rotating or fixing the paper API key pair; the full
live suite (`test/live/alpaca-broker-live-test.el`, 78 tests covering all
91 endpoints plus flows) is written and ready to run the moment
credentials work — rerun via `test/live/run-live-tests.sh` and update this
table from its output.

## Trading API

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v2/account` | `alpaca-broker-account` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/account/configurations` | `alpaca-broker-account-configurations` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `PATCH /v2/account/configurations` | `alpaca-broker-update-account-configurations` / `-sync` | yes | blocked: invalid paper credentials (401) | Not order-mutating (account settings, not orders); not gated by `alpaca-broker-allow-orders`. |
| `GET /v2/account/activities` | `alpaca-broker-account-activities` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | Paginates via `page_token` = previous page's last activity `id`, not `next_page_token`; `-all-sync` is a bespoke loop, not `alpaca-broker--fetch-all-pages-sync`. |
| `GET /v2/account/activities/{activity_type}` | `alpaca-broker-account-activities-by-type` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/account/portfolio/history` | `alpaca-broker-portfolio-history` / `-sync` | yes | blocked: invalid paper credentials (401) | Not paginated. |
| `GET /v2/orders` | `alpaca-broker-orders` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `POST /v2/orders` | `alpaca-broker-create-order` / `-sync` | yes | blocked: invalid paper credentials (401) | Gated by `alpaca-broker-allow-orders`. Live-test flow places 1 share SPY limit @ $1.00 (far below market), then replaces and cancels it. |
| `GET /v2/orders/{order_id}` | `alpaca-broker-order` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/orders:by_client_order_id` | `alpaca-broker-order-by-client-id` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `PATCH /v2/orders/{order_id}` | `alpaca-broker-replace-order` / `-sync` | yes | blocked: invalid paper credentials (401) | Gated. |
| `DELETE /v2/orders/{order_id}` | `alpaca-broker-cancel-order` / `-sync` | yes | blocked: invalid paper credentials (401) | Gated. |
| `DELETE /v2/orders` | `alpaca-broker-cancel-all-orders` / `-sync` | yes | blocked: invalid paper credentials (401) | Gated. |
| `GET /v2/positions` | `alpaca-broker-positions` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/positions/{symbol_or_asset_id}` | `alpaca-broker-position` / `-sync` | yes | skipped: no position (fresh paper account has none); blocked from even attempting: invalid paper credentials (401) | |
| `DELETE /v2/positions/{symbol_or_asset_id}` | `alpaca-broker-close-position` / `-sync` | yes | skipped: no position; blocked: invalid paper credentials (401) | Gated. Only closes a position this session created. |
| `DELETE /v2/positions` | `alpaca-broker-close-all-positions` / `-sync` | yes | skipped: no position; blocked: invalid paper credentials (401) | Gated. |
| `POST /v2/positions/{symbol_or_contract_id}/exercise` | `alpaca-broker-exercise-position` / `-sync` | yes | skipped: no held option position; blocked: invalid paper credentials (401) | Gated. |
| `POST /v2/positions/{symbol_or_contract_id}/do-not-exercise` | `alpaca-broker-decline-exercise-position` / `-sync` | yes | skipped: no held option position; blocked: invalid paper credentials (401) | Gated. |
| `GET /v2/assets` | `alpaca-broker-assets` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/assets/{symbol_or_asset_id}` | `alpaca-broker-asset` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/options/contracts` | `alpaca-broker-option-contracts` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | Paginates via `next_page_token` under key `option_contracts`. |
| `GET /v2/options/contracts/{symbol_or_id}` | `alpaca-broker-option-contract` / `-sync` | yes | blocked: invalid paper credentials (401) | Live test discovers a real active AAPL contract symbol via the list endpoint first. |
| `GET /v2/corporate_actions/announcements` | `alpaca-broker-corporate-action-announcements` / `-sync` | yes | blocked: invalid paper credentials (401) | Deprecated by Alpaca in favor of the market-data flavor below, but still live on the Trading API host, so implemented for full coverage. |
| `GET /v2/corporate_actions/announcements/{id}` | `alpaca-broker-corporate-action-announcement` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/watchlists` | `alpaca-broker-watchlists` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `POST /v2/watchlists` | `alpaca-broker-create-watchlist` / `-sync` | yes | blocked: invalid paper credentials (401) | Not gated (no financial risk). Live-test flow creates, exercises every op below, then deletes. |
| `GET /v2/watchlists/{watchlist_id}` | `alpaca-broker-watchlist` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `PUT /v2/watchlists/{watchlist_id}` | `alpaca-broker-update-watchlist` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `POST /v2/watchlists/{watchlist_id}` (add asset) | `alpaca-broker-add-watchlist-asset` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `DELETE /v2/watchlists/{watchlist_id}/{symbol}` | `alpaca-broker-remove-watchlist-asset` / `-sync` | yes | blocked: invalid paper credentials (401) | No by-name equivalent exists in Alpaca's API. |
| `DELETE /v2/watchlists/{watchlist_id}` | `alpaca-broker-delete-watchlist` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/watchlists:by_name` | `alpaca-broker-watchlist-by-name` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `PUT /v2/watchlists:by_name` | `alpaca-broker-update-watchlist-by-name` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `POST /v2/watchlists:by_name` (add asset) | `alpaca-broker-add-watchlist-asset-by-name` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `DELETE /v2/watchlists:by_name` | `alpaca-broker-delete-watchlist-by-name` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/calendar` | `alpaca-broker-calendar` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/clock` | `alpaca-broker-clock` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/wallets` | `alpaca-broker-wallets` / `-sync` | yes | blocked: invalid paper credentials (401) | Crypto Funding — confirmed genuinely part of the Trading API spec (tag "Crypto Funding"), not Broker-API-only. Alpaca's own spec declares zero query params despite prose mentioning an asset filter — flagged as a spec inconsistency by the research pass; implemented as documented. |
| `GET /v2/wallets/fees/estimate` | `alpaca-broker-wallet-fee-estimate` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/wallets/transfers` | `alpaca-broker-wallet-transfers` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `POST /v2/wallets/transfers` | `alpaca-broker-create-wallet-transfer` / `-sync` | yes | **skipped by design**: never live-tested — an on-chain crypto withdrawal is irreversible, unlike a paper trade or a watchlist edit | Gated by `alpaca-broker-allow-orders` (this package's own judgment call: Alpaca doesn't call this an "order," but it moves real crypto, so it gets the same safety gate). |
| `GET /v2/wallets/transfers/{transfer_id}` | `alpaca-broker-wallet-transfer` / `-sync` | yes | skipped: no existing transfer to fetch; blocked: invalid paper credentials (401) | |
| `GET /v2/wallets/travel-rule/vasps` | `alpaca-broker-wallet-vasps` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/wallets/whitelists` | `alpaca-broker-wallet-whitelist-addresses` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `POST /v2/wallets/whitelists` | `alpaca-broker-create-wallet-whitelist-address` / `-sync` | yes | **skipped by design**: pairs with the withdrawal above | Gated. |
| `DELETE /v2/wallets/whitelists/{whitelisted_address_id}` | `alpaca-broker-delete-wallet-whitelist-address` / `-sync` | yes | **skipped by design**: nothing was ever created to delete | Gated. |
| `PATCH /v2/wallets/whitelists/{whitelisted_address_id}/travel-rule-info` | `alpaca-broker-update-wallet-whitelist-travel-rule-info` / `-sync` | yes | **skipped by design**: nothing was ever created to update | Gated. |

### Explicitly out of scope (Trading API)

- `/v3/calendar/{market}`, `/v3/clock` — newer multi-market versions; the task named `/v2/calendar` and `/v2/clock` specifically.
- `/v2/tokenization/*` (mint, list/get tokenization requests) — Alpaca's Instant Tokenization Network; adjacent to Crypto Funding but not requested.
- `/v1/locates/*` — short-sale locate/quote API; Alpaca's own docs state it is unsupported in paper trading, and it wasn't requested.
- Broker API (account opening, funding, journals, ACATS, KYC) and all streaming/WebSocket/SSE endpoints (including `/v2beta1/events/activities` SSE) — excluded per task scope.

## Market Data API

### Stocks

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v2/stocks/bars` (multi) | `alpaca-broker-stocks-bars` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/bars` (single) | `alpaca-broker-bars` / `-sync` | yes | blocked: invalid paper credentials (401) | Pre-existing function, kept as-is. |
| `GET /v2/stocks/bars/latest` (multi) | `alpaca-broker-stocks-latest-bars` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/bars/latest` (single) | `alpaca-broker-latest-bar` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/trades` (multi) | `alpaca-broker-stocks-trades` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/trades` (single) | `alpaca-broker-trades` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/trades/latest` (multi) | `alpaca-broker-stocks-latest-trades` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/trades/latest` (single) | `alpaca-broker-latest-trade` / `-sync` | yes | blocked: invalid paper credentials (401) | Pre-existing function, kept as-is. |
| `GET /v2/stocks/quotes` (multi) | `alpaca-broker-stocks-quotes` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/quotes` (single) | `alpaca-broker-quotes` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/quotes/latest` (multi) | `alpaca-broker-stocks-latest-quotes` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/quotes/latest` (single) | `alpaca-broker-latest-quote` / `-sync` | yes | blocked: invalid paper credentials (401) | Pre-existing function, kept as-is. |
| `GET /v2/stocks/snapshots` (multi) | `alpaca-broker-stocks-snapshots` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/{symbol}/snapshot` (single) | `alpaca-broker-snapshot` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/auctions` (multi) | `alpaca-broker-stocks-auctions` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | `feed` is `sip`-only for this endpoint per Alpaca's spec. |
| `GET /v2/stocks/{symbol}/auctions` (single) | `alpaca-broker-auctions` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v2/stocks/meta/conditions/{tickType}` | `alpaca-broker-stocks-condition-codes` / `-sync` | yes | blocked: invalid paper credentials (401) | Requires `tape` query param (A/B/C). |
| `GET /v2/stocks/meta/exchanges` | `alpaca-broker-stocks-exchange-codes` / `-sync` | yes | blocked: invalid paper credentials (401) | |

### Options

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta1/options/bars` | `alpaca-broker-options-bars` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | Live test discovers a real active AAPL contract symbol first. |
| `GET /v1beta1/options/trades` | `alpaca-broker-options-trades` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta1/options/trades/latest` | `alpaca-broker-options-latest-trades` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta1/options/quotes/latest` | `alpaca-broker-options-latest-quotes` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta1/options/snapshots` | `alpaca-broker-options-snapshots` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta1/options/snapshots/{underlying_symbol}` (chain) | `alpaca-broker-options-chain` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta1/options/meta/conditions/{tickType}` | `alpaca-broker-options-condition-codes` / `-sync` | yes | blocked: invalid paper credentials (401) | No `tape` param, unlike the stock version. |
| `GET /v1beta1/options/meta/exchanges` | `alpaca-broker-options-exchange-codes` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| — no historical `bars/latest`, no historical `quotes`, no `auctions` for options — | — | — | — | Not published by Alpaca as of this research pass; nothing to implement. |

### Crypto

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta3/crypto/{loc}/bars` | `alpaca-broker-crypto-bars` / `-sync` (single, unwrapped) + `alpaca-broker-crypto-bars-multi` / `-sync` / `-all-sync` (raw, multi) | yes | blocked: invalid paper credentials (401) | `loc` defaults to `"us"`; every crypto function takes an optional trailing LOC arg. |
| `GET /v1beta3/crypto/{loc}/latest/bars` | `alpaca-broker-crypto-latest-bars-multi` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta3/crypto/{loc}/trades` | `alpaca-broker-crypto-trades-multi` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta3/crypto/{loc}/latest/trades` | `alpaca-broker-crypto-latest-trade` / `-sync` (single, unwrapped) + `alpaca-broker-crypto-latest-trades-multi` / `-sync` (raw, multi) | yes | blocked: invalid paper credentials (401) | `crypto-latest-trade` is a pre-existing function, kept as-is. |
| `GET /v1beta3/crypto/{loc}/quotes` | `alpaca-broker-crypto-quotes-multi` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta3/crypto/{loc}/latest/quotes` | `alpaca-broker-crypto-latest-quote` / `-sync` (single, unwrapped) + `alpaca-broker-crypto-latest-quotes-multi` / `-sync` (raw, multi) | yes | blocked: invalid paper credentials (401) | `crypto-latest-quote` is a pre-existing function, kept as-is. |
| `GET /v1beta3/crypto/{loc}/latest/orderbooks` | `alpaca-broker-crypto-latest-orderbooks-multi` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| `GET /v1beta3/crypto/{loc}/snapshots` | `alpaca-broker-crypto-snapshots-multi` / `-sync` | yes | blocked: invalid paper credentials (401) | |
| — `/v1beta1/crypto/xbbos/latest`, `/v1beta1/crypto/meta/spreads` — | — | — | — | Belonged to the retired `v1beta1` crypto surface; absent from the current `v1beta3` reference. Not implemented — deprecated/removed by Alpaca, not a gap. |

### Forex

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta1/forex/rates` | `alpaca-broker-forex-rates` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | Confirmed public. Only rate (bid/ask/mid) endpoints exist for forex — no bars/trades/quotes/snapshots. |
| `GET /v1beta1/forex/latest/rates` | `alpaca-broker-forex-latest-rates` / `-sync` | yes | blocked: invalid paper credentials (401) | |

### Fixed Income

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta1/fixed_income/latest/prices` | `alpaca-broker-fixed-income-latest-prices` / `-sync` | yes | blocked: invalid paper credentials (401) | Confirmed public, latest-only (no historical bars/trades published). Keyed by ISIN, not symbol. Likely tier-gated on this account — record the actual status/error once credentials work. |
| `GET /v1beta1/fixed_income/latest/quotes` | `alpaca-broker-fixed-income-latest-quotes` / `-sync` | yes | blocked: invalid paper credentials (401) | Same tier caveat. |

### News

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta1/news` | `alpaca-broker-news` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | |

### Screener

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta1/screener/stocks/most-actives` | `alpaca-broker-screener-most-actives` / `-sync` | yes | blocked: invalid paper credentials (401) | Alpaca docs note this uses real-time SIP data; may return a less complete result without a SIP-eligible plan. |
| `GET /v1beta1/screener/{market_type}/movers` | `alpaca-broker-screener-movers` / `-sync` | yes | blocked: invalid paper credentials (401) | `market_type` is `"stocks"` or `"crypto"`; no separate crypto most-actives endpoint exists. |

### Logos

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1beta1/logos/{symbol}` | `alpaca-broker-logo-sync` | yes | blocked: invalid paper credentials (401) | Returns a raw PNG byte string, not JSON — sync-only, no async form (no JSON callback to dispatch to). Alpaca's docs say Logo API pricing is by sales inquiry; may be gated on this account tier — record the actual status once credentials work. |

### Corporate Actions (market-data flavor)

| Method + path | Elisp function(s) | Mocked test | Live-tested | Notes |
| --- | --- | --- | --- | --- |
| `GET /v1/corporate-actions` | `alpaca-broker-corporate-actions` / `-sync` / `-all-sync` | yes | blocked: invalid paper credentials (401) | Note the `/v1/` path (not `/v1beta1/` or `/v2/`), on the market-data host. This is Alpaca's documented replacement for the deprecated Trading-API `/v2/corporate_actions/announcements`; response nests many typed arrays under one `corporate_actions` key, so its `-all-sync` uses a bespoke per-type merge (`alpaca-broker--merge-corporate-actions-pages`), not the generic keyed-list/keyed-object mergers. |

### Explicitly out of scope (Market Data API)

- All streaming/WebSocket/SSE endpoints, including the Corporate Actions Events SSE feed — excluded per task scope.

## Totals

- **91 / 91** in-scope endpoints implemented (48 Trading API + 43 Market Data API).
- **163 / 163** mocked ERT tests passing (`test/*.el`, excludes `test/live/`).
- **0 / 91** live-verified so far — all blocked on the invalid paper API credentials described above. The live suite (`test/live/alpaca-broker-live-test.el`, 78 tests) is complete: it skips cleanly (0 unexpected) with no credentials set, and was actually run once against the (currently invalid) resolved credentials, confirming every call genuinely reaches Alpaca and is rejected rather than silently no-opping. Rerun it and update this table once credentials are fixed.
