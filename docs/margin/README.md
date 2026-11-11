# Alpaca margin, options and account-rule captures

Fetched 2026-11-10 with curl from Alpaca's ReadMe docs (the `.md` export
of each page, e.g. `https://docs.alpaca.markets/docs/<page>.md`). Each
file starts with its source URL and fetch date. These are the sources
cited by `alpaca-broker-model.el` (rule cells registered with the sibling
package `../broker-model.el`).

| file | URL | what it specifies |
|---|---|---|
| margin-and-short-selling.md | https://docs.alpaca.markets/docs/margin-and-short-selling | $2,000 equity for margin and shorting (else 1x); 2x overnight / 4x intraday; Reg T 50% initial; maintenance table (long < $2.50 100%, $2.50-$6 50%, > $6 30%, 2x ETF 50%, 3x ETF 75%; short < $5 greater of $2.50/sh or 100%, >= $5 greater of $5/sh or 30%); concentration (>= 70% in one name with >= $100,000 margin balance -> 50%); margin interest; ETB/HTB locates |
| trading-account.md | https://docs.alpaca.markets/docs/account-plans | all accounts opened as margin accounts; no retirement accounts on the Trading API; crypto not margin collateral; account object and the `buying_power` formulas by `multiplier` (1 = cash, 2 = max(equity - initial_margin, 0) x 2, 4 = (last_equity - last_maintenance_margin) x 4); sample object used as a test vector |
| options-trading.md | https://docs.alpaca.markets/docs/options-trading | options levels 0-3 (L1 covered call, cash-secured put; L2 + long calls/puts; L3 + call/put spreads); expiry and exercise handling |
| options-level-3-trading.md | https://docs.alpaca.markets/docs/options-level-3-trading | multi-leg orders; universal spread rule (maintenance = worst intrinsic payoff, premiums ignored, per expiration, largest used); cost basis = maintenance + net price; four-call and credit-spread examples; MLeg uncovered-leg restriction |
| options-trading-overview-broker-api.md | https://docs.alpaca.markets/us/docs/options-trading-overview | Broker API options approval; buying power checks (long options pay premium; covered call needs shares; cash-secured put needs strike x 100 - premium, "required: 20310"); expiration handling |
| intraday-margin-rule.md | https://docs.alpaca.markets/us/docs/the-intraday-margin-rule | FINRA intraday margin rule replaces PDT at Alpaca: no trade count, no $25,000 minimum; IML / IMD; call due in 2 business days; 90-day freeze after the 5th; de minimis lesser of $1,000 or 5% equity |
| intraday-margin-rule-non-leverage.md | https://docs.alpaca.markets/us/docs/understanding-the-new-intraday-margin-rule | same rule for non-leverage margin accounts (margin used to avoid T+1 settlement delays) |
| end-of-pdt.md | https://docs.alpaca.markets/us/docs/understanding-finras-new-intraday-margin-rule-and-the-end-of-pdt | background on the FINRA 4210 amendment; 12-month transition in which firms may apply either regime; PM accounts >= $5M exempt |
| ira-accounts-overview-broker-api.md | https://docs.alpaca.markets/us/docs/ira-accounts-overview | Broker API IRAs: limited margin (1x), options up to level 2, no crypto |
| index-options.md | https://docs.alpaca.markets/us/docs/index-options | index options: European, cash-settled; same L1-L3 levels; no calendars |
| user-protection.md | https://docs.alpaca.markets/docs/user-protection | equity/order ratio check (position 600% of equity -> closing only); wash-trade rejection |
| crypto-trading.md | https://docs.alpaca.markets/docs/crypto-trading | crypto spot trading (not marginable) |
| MarginDiscStmt.pdf | https://files.alpaca.markets/disclosures/library/MarginDiscStmt.pdf | Alpaca Margin Disclosure Statement: house maintenance may rise without notice; no extension right |

Not published by Alpaca (as of the fetch): the `options_buying_power`
formula; maintenance for short leveraged ETFs; whether shares under
$2.50 are marginable for initial margin; whether options levels differ
for 1x (limited margin) accounts.
