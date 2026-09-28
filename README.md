# alpaca-broker.el

A pure-Elisp client for the [Alpaca Markets](https://alpaca.markets) API:
market data (`https://data.alpaca.markets`) and a read-only slice of the
trading API (`https://api.alpaca.markets` / `https://paper-api.alpaca.markets`).

No external Elisp dependencies. HTTP goes through the built-in `url.el`
(`url-retrieve` for async calls, `url-retrieve-synchronously` for blocking
calls); JSON is parsed with the built-in `json-parse-buffer`. Requires Emacs
27.1+.

## Files

- `alpaca-broker.el` — core: defcustoms, credential resolution,
  HTTP/JSON/error plumbing. Load this or `require` it transitively via the
  files below.
- `alpaca-broker-data.el` — market-data endpoints (quotes, trades, bars;
  stocks and crypto) plus the `alpaca-broker-show-quote` demo command.
- `alpaca-broker-trading.el` — read-only trading endpoints (account,
  positions, orders).

## Install

### straight.el

```elisp
(straight-use-package
 '(alpaca-broker :type git :host github :repo "davidawad/alpaca-broker.el"
                 :files ("alpaca-broker.el" "alpaca-broker-data.el"
                         "alpaca-broker-trading.el")))
```

### use-package + straight.el

```elisp
(use-package alpaca-broker
  :straight (:type git :host github :repo "davidawad/alpaca-broker.el"
             :files ("alpaca-broker.el" "alpaca-broker-data.el"
                     "alpaca-broker-trading.el"))
  :commands (alpaca-broker-show-quote))
```

### Manual

Copy `alpaca-broker.el`, `alpaca-broker-data.el`, and
`alpaca-broker-trading.el` onto your `load-path`, then:

```elisp
(require 'alpaca-broker-data)     ; market data (pulls in alpaca-broker.el)
(require 'alpaca-broker-trading)  ; account/positions/orders (pulls in alpaca-broker.el)
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

- which trading-API host `alpaca-broker-account`/`alpaca-broker-positions`/
  `alpaca-broker-orders` hit — `https://paper-api.alpaca.markets` when
  non-nil, else `https://api.alpaca.markets`;
- which pair of environment variables the credential fallback reads (see
  above).

Market data (`https://data.alpaca.markets`) is unaffected by
`alpaca-broker-paper` — Alpaca serves the same market-data API regardless of
paper vs live.

```elisp
(setq alpaca-broker-paper nil) ; switch to live trading
```

## Commands and functions

Every market-data and trading fetcher below has two forms:
`alpaca-broker-FOO` (asynchronous — takes a `CALLBACK` as its last required
argument, called with the parsed JSON alist) and `alpaca-broker-FOO-sync`
(synchronous — blocks up to `alpaca-broker-timeout` seconds and returns the
parsed JSON alist directly).

### Market data (`alpaca-broker-data.el`)

| Function | Description |
| --- | --- |
| `alpaca-broker-latest-quote` / `-sync` | Latest bid/ask quote for a stock symbol. |
| `alpaca-broker-latest-trade` / `-sync` | Latest trade print for a stock symbol. |
| `alpaca-broker-bars` / `-sync` | Historical OHLCV bars for a stock symbol at a given timeframe (`"1Min"`, `"15Min"`, `"1Day"`, ...), optionally windowed by start/end and capped at a limit. |
| `alpaca-broker-crypto-latest-quote` / `-sync` | Latest bid/ask quote for a crypto symbol (e.g. `"BTC/USD"`). |
| `alpaca-broker-crypto-latest-trade` / `-sync` | Latest trade print for a crypto symbol. |
| `alpaca-broker-crypto-bars` / `-sync` | Historical OHLCV bars for a crypto symbol. |
| `alpaca-broker-show-quote` | Interactive demo command: prompts for a stock symbol, shows its bid/ask in the minibuffer. |

### Trading, read-only (`alpaca-broker-trading.el`)

| Function | Description |
| --- | --- |
| `alpaca-broker-account` / `-sync` | The Alpaca trading account (cash, buying power, status, ...). |
| `alpaca-broker-positions` / `-sync` | Every open position. |
| `alpaca-broker-orders` / `-sync` | Orders, optionally filtered by an alist of Alpaca's own query parameters (e.g. `'(("status" . "open"))`). |

Deliberately **not** implemented in this version: placing, replacing, or
canceling orders (any endpoint that mutates account state). See Roadmap.

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

## Roadmap

- Order placement/replacement/cancellation (`POST`/`PATCH`/`DELETE`
  `/v2/orders`) — deliberately out of scope for this read-only v1.
- WebSocket streaming (Alpaca's real-time trade/quote/bar and
  order-update streams) — `url.el` alone doesn't do WebSocket; this would
  need a separate transport.

## Tests

ERT tests live in `test/alpaca-broker-test.el` and mock at the
`url-retrieve`/`url-retrieve-synchronously` boundary — no real network
calls. Run standalone:

```sh
emacs -Q --batch -L . -l alpaca-broker.el -l alpaca-broker-data.el \
  -l alpaca-broker-trading.el -l test/alpaca-broker-test.el \
  -f ert-run-tests-batch-and-exit
```

## License

MIT — see [LICENSE](LICENSE).
