# alpaca-broker.el

A pure-Elisp client for the [Alpaca Markets](https://alpaca.markets) API,
with full coverage of the **Trading API**
(`https://api.alpaca.markets` / `https://paper-api.alpaca.markets`) and the
**Market Data API** (`https://data.alpaca.markets`). Out of scope by design:
the Broker API (account opening, funding, journals, ACATS, KYC) and
streaming/WebSocket/SSE. See [ROADMAP.md](ROADMAP.md) for the full
endpoint-by-endpoint coverage matrix.

No external Elisp dependencies. HTTP goes through the built-in `url.el`
(`url-retrieve` for async calls, `url-retrieve-synchronously` for blocking
calls); JSON is parsed with the built-in `json-parse-buffer`. Requires Emacs
27.1+.

## Files

- `alpaca-broker.el` — core: defcustoms, credential resolution,
  HTTP/JSON/error plumbing, the order-safety gate, and the pagination
  helpers. Load this or `require` it transitively via the files below.
- `alpaca-broker-trading.el` — account, account configurations, account
  activities, portfolio history, assets, option contracts, the deprecated
  v2 corporate-action announcements, the market calendar, and the market
  clock. Entirely read-only.
- `alpaca-broker-orders.el` — orders (list, get, create, replace, cancel)
  and positions (list, get, close), plus option exercise/decline-exercise.
  Order-mutating functions are gated, see Order safety below.
- `alpaca-broker-watchlists.el` — full watchlist CRUD, both by id and by
  name.
- `alpaca-broker-wallets.el` — crypto funding wallets: balances, fee
  estimates, transfers, VASP search, and whitelisted withdrawal addresses.
  Transfer/whitelist-mutating functions are gated, see Order safety below.
- `alpaca-broker-data-stocks.el` — stock market data: historical/latest
  bars, trades, quotes, snapshots, auctions, condition/exchange-code
  metadata, plus the `alpaca-broker-show-quote` demo command.
- `alpaca-broker-data-options.el` — option market data: historical
  bars/trades, latest trades/quotes, snapshots, the option chain, and
  condition/exchange-code metadata.
- `alpaca-broker-data-crypto.el` — crypto market data: historical/latest
  bars, trades, quotes, order books, and snapshots.
- `alpaca-broker-data-news.el` — news articles.
- `alpaca-broker-data-misc.el` — forex rates, fixed-income latest
  prices/quotes, the stock/crypto screener, symbol logos, and the
  market-data flavor of corporate actions.

## Install

### straight.el

```elisp
(straight-use-package
 '(alpaca-broker :type git :host github :repo "davidawad/alpaca-broker.el"
                 :files ("alpaca-broker.el" "alpaca-broker-*.el")))
```

### use-package + straight.el

```elisp
(use-package alpaca-broker
  :straight (:type git :host github :repo "davidawad/alpaca-broker.el"
             :files ("alpaca-broker.el" "alpaca-broker-*.el"))
  :commands (alpaca-broker-show-quote))
```

### Manual

Copy every `alpaca-broker*.el` file onto your `load-path`, then `require`
whichever module(s) you need -- each pulls in `alpaca-broker.el`
transitively:

```elisp
(require 'alpaca-broker-data-stocks)
(require 'alpaca-broker-orders)
;; etc.
```

## Auth setup

alpaca-broker.el needs an Alpaca API key ID + secret key pair (the same pair
Alpaca's dashboard issues for both paper and live trading — it's the base
URL that differs, not the credentials). Resolved in this order:

1. `alpaca-broker-api-key` / `alpaca-broker-api-secret` (Lisp variables), if
   both are set.
2. An `auth-source` entry for host `alpaca-broker-auth-source-host` (default
   `"data.alpaca.markets"`) whose `login` field holds the key ID and whose
   `password` field holds the secret key. Sample line in `~/.authinfo.gpg`:

   ```
   machine data.alpaca.markets login AKFZEXAMPLEKEYID password ExampleSecretKeyGoesHere
   ```

3. Environment variables: `ALPACA_API_PAPER_KEY` / `ALPACA_API_PAPER_SECRET`
   when `alpaca-broker-paper` is non-nil (the default), else
   `ALPACA_API_KEY` / `ALPACA_API_SECRET`.

If none of the three resolves, every request signals a `user-error` with
setup instructions instead of failing opaquely.

## Paper vs live

`alpaca-broker-paper` (default `t`) controls two things:

- which trading-API host every `alpaca-broker-trading.el` /
  `-orders.el` / `-watchlists.el` / `-wallets.el` function hits —
  `https://paper-api.alpaca.markets` when non-nil, else
  `https://api.alpaca.markets`;
- which pair of environment variables the credential fallback reads (see
  above).

Market data (`https://data.alpaca.markets`) is unaffected by
`alpaca-broker-paper` — Alpaca serves the same market-data API regardless of
paper vs live.

```elisp
(setq alpaca-broker-paper nil) ; switch to live trading
```

## Order safety

Order-mutating requests are **gated, not absent**. Every function that
places, replaces, or cancels an order; closes a position; exercises or
declines an option contract; or requests/mutates a crypto-funding
withdrawal or whitelisted address, calls
`alpaca-broker--require-order-permission` first, which signals a
`user-error` unless the defcustom `alpaca-broker-allow-orders` is non-nil:

```elisp
(alpaca-broker-create-order-sync
 '(("symbol" . "SPY") ("qty" . "1") ("side" . "buy")
   ("type" . "limit") ("time_in_force" . "day") ("limit_price" . "1.00")))
;; => user-error: order-mutating requests are disabled; set
;;    `alpaca-broker-allow-orders' to non-nil to enable them

(let ((alpaca-broker-allow-orders t))
  (alpaca-broker-create-order-sync ...)) ; now goes through
```

`alpaca-broker-allow-orders` defaults to `nil`, so no order-mutating
request can ever fire by accident — a caller must explicitly opt in (and
should keep `alpaca-broker-paper` non-nil, its own default, while doing
so). Crypto-wallet withdrawal/whitelist mutation is gated the same way as
a matter of this package's own judgment: Alpaca's docs don't call it an
"order," but an on-chain transfer is at least as irreversible as a trade.

Read-only functions (listing orders/positions, market data, account info,
watchlists, calendar/clock, ...) are never gated.

## Commands and functions

Every fetcher below has two forms: `alpaca-broker-FOO` (asynchronous —
takes a `CALLBACK` as its last required argument, called with the parsed
JSON alist) and `alpaca-broker-FOO-sync` (synchronous — blocks up to
`alpaca-broker-timeout` seconds and returns the parsed JSON alist
directly), unless noted otherwise. Endpoints whose response paginates via
Alpaca's `next_page_token` also have an `alpaca-broker-FOO-all-sync` form
that fetches every page via `alpaca-broker--fetch-all-pages-sync` and
returns the merged result.

Multi-symbol endpoints take a `SYMBOLS` argument, either a comma-joined
string or a list of strings (`alpaca-broker--join-symbols`). Optional
Alpaca query parameters are passed as a trailing `PARAMS` alist, e.g.
`'(("limit" . "10") ("feed" . "iex"))`, straight through to the request —
same convention already established by `alpaca-broker-orders`.

### Trading (`alpaca-broker-trading.el`) — read-only

| Function | Description |
| --- | --- |
| `alpaca-broker-account` / `-sync` | The trading account (cash, buying power, status, ...). |
| `alpaca-broker-account-configurations` / `-sync` | Current account trading configuration. |
| `alpaca-broker-update-account-configurations` / `-sync` | Patch account trading configuration. Not gated (account settings, not orders). |
| `alpaca-broker-account-activities` / `-sync` / `-all-sync` | Every account activity (trade + non-trade), paginated by `page_token`/last activity id. |
| `alpaca-broker-account-activities-by-type` / `-sync` | Account activities of one activity type. |
| `alpaca-broker-portfolio-history` / `-sync` | Portfolio equity/P&L history. |
| `alpaca-broker-assets` / `-sync` | Tradable assets, optionally filtered. |
| `alpaca-broker-asset` / `-sync` | One asset by symbol or asset id. |
| `alpaca-broker-option-contracts` / `-sync` / `-all-sync` | Option contracts, optionally filtered. |
| `alpaca-broker-option-contract` / `-sync` | One option contract by symbol or id. |
| `alpaca-broker-corporate-action-announcements` / `-sync` | Deprecated v2 corporate-action announcements (Trading API host). |
| `alpaca-broker-corporate-action-announcement` / `-sync` | One announcement by id. |
| `alpaca-broker-calendar` / `-sync` | Market calendar. |
| `alpaca-broker-clock` / `-sync` | Market clock (`is_open`, `next_open`, `next_close`). |

### Orders and positions (`alpaca-broker-orders.el`)

| Function | Description | Gated |
| --- | --- | --- |
| `alpaca-broker-orders` / `-sync` | List orders, optionally filtered. | no |
| `alpaca-broker-order` / `-sync` | One order by id. | no |
| `alpaca-broker-order-by-client-id` / `-sync` | One order by client order id. | no |
| `alpaca-broker-create-order` / `-sync` | Place an order. | **yes** |
| `alpaca-broker-replace-order` / `-sync` | Replace (amend) an order. | **yes** |
| `alpaca-broker-cancel-order` / `-sync` | Cancel one order. | **yes** |
| `alpaca-broker-cancel-all-orders` / `-sync` | Cancel every open order. | **yes** |
| `alpaca-broker-positions` / `-sync` | List every open position. | no |
| `alpaca-broker-position` / `-sync` | One position by symbol or asset id. | no |
| `alpaca-broker-close-position` / `-sync` | Close one position. | **yes** |
| `alpaca-broker-close-all-positions` / `-sync` | Close every position. | **yes** |
| `alpaca-broker-exercise-position` / `-sync` | Exercise a held option contract. | **yes** |
| `alpaca-broker-decline-exercise-position` / `-sync` | Submit a do-not-exercise instruction. | **yes** |

### Watchlists (`alpaca-broker-watchlists.el`) — not gated (no financial risk)

| Function | Description |
| --- | --- |
| `alpaca-broker-watchlists` / `-sync` | List every watchlist (summary form). |
| `alpaca-broker-create-watchlist` / `-sync` | Create a watchlist. |
| `alpaca-broker-watchlist` / `-sync` | Get one watchlist by id. |
| `alpaca-broker-update-watchlist` / `-sync` | Update one watchlist by id (rename and/or replace its assets). |
| `alpaca-broker-add-watchlist-asset` / `-sync` | Add one symbol to a watchlist by id. |
| `alpaca-broker-remove-watchlist-asset` / `-sync` | Remove one symbol from a watchlist by id. |
| `alpaca-broker-delete-watchlist` / `-sync` | Delete a watchlist by id. |
| `alpaca-broker-watchlist-by-name` / `-sync` | Get one watchlist by name. |
| `alpaca-broker-update-watchlist-by-name` / `-sync` | Update one watchlist by name. |
| `alpaca-broker-add-watchlist-asset-by-name` / `-sync` | Add one symbol to a watchlist by name. |
| `alpaca-broker-delete-watchlist-by-name` / `-sync` | Delete a watchlist by name. There is no by-name "remove one symbol" — use the by-id form. |

### Crypto funding wallets (`alpaca-broker-wallets.el`)

| Function | Description | Gated |
| --- | --- | --- |
| `alpaca-broker-wallets` / `-sync` | List (or lazily create) crypto wallets. | no |
| `alpaca-broker-wallet-fee-estimate` / `-sync` | Estimate on-chain fee for a proposed withdrawal. | no |
| `alpaca-broker-wallet-transfers` / `-sync` | List every wallet transfer. | no |
| `alpaca-broker-wallet-transfer` / `-sync` | One transfer by id. | no |
| `alpaca-broker-wallet-vasps` / `-sync` | Search the Notabene VASP directory (travel-rule lookups). | no |
| `alpaca-broker-wallet-whitelist-addresses` / `-sync` | List whitelisted withdrawal addresses. | no |
| `alpaca-broker-create-wallet-transfer` / `-sync` | Request an on-chain withdrawal. | **yes** |
| `alpaca-broker-create-wallet-whitelist-address` / `-sync` | Request a new whitelisted address. | **yes** |
| `alpaca-broker-delete-wallet-whitelist-address` / `-sync` | Delete a whitelisted address. | **yes** |
| `alpaca-broker-update-wallet-whitelist-travel-rule-info` / `-sync` | Update a whitelisted address's travel-rule info. | **yes** |

### Stock market data (`alpaca-broker-data-stocks.el`)

Single-symbol functions (`SYMBOL`) hit `/v2/stocks/{symbol}/...`;
`stocks-`-prefixed functions (`SYMBOLS`) hit the multi-symbol
`/v2/stocks/...` endpoints.

| Function | Description |
| --- | --- |
| `alpaca-broker-bars` / `-sync` | Historical bars for one symbol. |
| `alpaca-broker-stocks-bars` / `-sync` / `-all-sync` | Historical bars for multiple symbols. |
| `alpaca-broker-latest-bar` / `-sync` | Latest minute bar for one symbol. |
| `alpaca-broker-stocks-latest-bars` / `-sync` | Latest minute bar for multiple symbols. |
| `alpaca-broker-trades` / `-sync` / `-all-sync` | Historical trades for one symbol. |
| `alpaca-broker-stocks-trades` / `-sync` / `-all-sync` | Historical trades for multiple symbols. |
| `alpaca-broker-latest-trade` / `-sync` | Latest trade for one symbol. |
| `alpaca-broker-stocks-latest-trades` / `-sync` | Latest trade for multiple symbols. |
| `alpaca-broker-latest-quote` / `-sync` | Latest bid/ask quote for one symbol. |
| `alpaca-broker-quotes` / `-sync` / `-all-sync` | Historical quotes (NBBO) for one symbol. |
| `alpaca-broker-stocks-quotes` / `-sync` / `-all-sync` | Historical quotes for multiple symbols. |
| `alpaca-broker-stocks-latest-quotes` / `-sync` | Latest quote for multiple symbols. |
| `alpaca-broker-snapshot` / `-sync` | Snapshot (latest trade/quote/bars) for one symbol. |
| `alpaca-broker-stocks-snapshots` / `-sync` | Snapshot for multiple symbols. |
| `alpaca-broker-auctions` / `-sync` / `-all-sync` | Opening/closing auctions for one symbol. |
| `alpaca-broker-stocks-auctions` / `-sync` / `-all-sync` | Opening/closing auctions for multiple symbols. |
| `alpaca-broker-stocks-condition-codes` / `-sync` | Trade/quote condition-code metadata. |
| `alpaca-broker-stocks-exchange-codes` / `-sync` | Exchange-code metadata. |
| `alpaca-broker-show-quote` | Interactive demo command: prompts for a symbol, shows its bid/ask in the minibuffer. |

### Option market data (`alpaca-broker-data-options.el`)

`SYMBOLS` is an OSI option contract symbol (or several, comma-joined/list).

| Function | Description |
| --- | --- |
| `alpaca-broker-options-bars` / `-sync` / `-all-sync` | Historical bars. |
| `alpaca-broker-options-trades` / `-sync` / `-all-sync` | Historical trades. |
| `alpaca-broker-options-latest-trades` / `-sync` | Latest trade. |
| `alpaca-broker-options-latest-quotes` / `-sync` | Latest quote. |
| `alpaca-broker-options-snapshots` / `-sync` / `-all-sync` | Snapshots. |
| `alpaca-broker-options-chain` / `-sync` / `-all-sync` | Option chain for an underlying symbol. |
| `alpaca-broker-options-condition-codes` / `-sync` | Condition-code metadata. |
| `alpaca-broker-options-exchange-codes` / `-sync` | Exchange-code metadata. |

### Crypto market data (`alpaca-broker-data-crypto.el`)

Every function takes an optional trailing `LOC` arg selecting the venue
(default `"us"`; also `"us-1"`, `"us-2"`, `"eu-1"`, `"bs-1"`).
`alpaca-broker-crypto-bars` / `-latest-trade` / `-latest-quote` are the
original single-symbol convenience wrappers (unwrap one symbol's entry out
of Alpaca's keyed-by-symbol response); every other function here is a raw
`-multi` fetcher returning the full response for every symbol requested.

| Function | Description |
| --- | --- |
| `alpaca-broker-crypto-bars` / `-sync` | Historical bars, one symbol, unwrapped. |
| `alpaca-broker-crypto-bars-multi` / `-sync` / `-all-sync` | Historical bars, multiple symbols, raw. |
| `alpaca-broker-crypto-latest-bars-multi` / `-sync` | Latest bar, multiple symbols. |
| `alpaca-broker-crypto-trades-multi` / `-sync` / `-all-sync` | Historical trades, multiple symbols. |
| `alpaca-broker-crypto-latest-trade` / `-sync` | Latest trade, one symbol, unwrapped. |
| `alpaca-broker-crypto-latest-trades-multi` / `-sync` | Latest trade, multiple symbols. |
| `alpaca-broker-crypto-quotes-multi` / `-sync` / `-all-sync` | Historical quotes, multiple symbols. |
| `alpaca-broker-crypto-latest-quote` / `-sync` | Latest quote, one symbol, unwrapped. |
| `alpaca-broker-crypto-latest-quotes-multi` / `-sync` | Latest quote, multiple symbols. |
| `alpaca-broker-crypto-latest-orderbooks-multi` / `-sync` | Latest order book, multiple symbols. |
| `alpaca-broker-crypto-snapshots-multi` / `-sync` | Snapshot, multiple symbols. |

### News (`alpaca-broker-data-news.el`)

| Function | Description |
| --- | --- |
| `alpaca-broker-news` / `-sync` / `-all-sync` | News articles, optionally filtered by symbol/date. |

### Forex, fixed income, screener, logos, corporate actions (`alpaca-broker-data-misc.el`)

| Function | Description |
| --- | --- |
| `alpaca-broker-forex-rates` / `-sync` / `-all-sync` | Historical forex rates (bid/ask/mid). |
| `alpaca-broker-forex-latest-rates` / `-sync` | Latest forex rates. |
| `alpaca-broker-fixed-income-latest-prices` / `-sync` | Latest fixed-income prices, keyed by ISIN. |
| `alpaca-broker-fixed-income-latest-quotes` / `-sync` | Latest fixed-income quotes, keyed by ISIN. |
| `alpaca-broker-screener-most-actives` / `-sync` | Most-active stocks by volume/trade-count. |
| `alpaca-broker-screener-movers` / `-sync` | Top gainers/losers for `"stocks"` or `"crypto"`. |
| `alpaca-broker-logo-sync` | A symbol's logo as a raw PNG byte string. Sync-only (binary response, no JSON to hand a callback). |
| `alpaca-broker-corporate-actions` / `-sync` / `-all-sync` | Corporate actions (market-data flavor, `/v1/corporate-actions` — the non-deprecated replacement for the Trading-API announcements endpoint above). |

## Errors

Any HTTP response outside the 2xx range signals `alpaca-broker-error` with
`(STATUS BODY-EXCERPT)` as its error data — callers never see a raw `url.el`
condition. `condition-case`-friendly:

```elisp
(condition-case err
    (alpaca-broker-account-sync)
  (alpaca-broker-error
   (message "Alpaca error %s: %s" (nth 1 err) (nth 2 err))))
```

## Tests

Two kinds — see `ROADMAP.md` for the full endpoint coverage matrix.

Mocked ERT tests, one file per source file (`test/alpaca-broker-*-test.el`,
sharing doubles from `test/alpaca-broker-test-helpers.el`), mock at the
`url-retrieve`/`url-retrieve-synchronously` boundary — no real network
calls. Run standalone:

```sh
emacs -Q --batch -L . -L test $(printf ' -l %s' test/*.el) \
  -f ert-run-tests-batch-and-exit
```

Live ERT tests against Alpaca's real paper API live in
`test/live/alpaca-broker-live-test.el`. Never run in CI; every test skips
itself unless `ALPACA_API_PAPER_KEY`/`ALPACA_API_PAPER_SECRET` are set.
Run with `test/live/run-live-tests.sh`.

## License

MIT — see [LICENSE](LICENSE).
