Source URL: https://docs.alpaca.markets/docs/user-protection
Fetched: 2026-11-10 (curl, Markdown export of the ReadMe docs page)
Capture note: verbatim page text; images not captured.

---

---
updatedAt: 2026-09-16T16:38:53.000Z
agentTools:
  siteIndex: https://docs.alpaca.markets/llms.txt
  projectIndex: https://docs.alpaca.markets/us/llms.txt
---

# User Protection

We have enabled several types of protections to enhance your trading experience.

1. [Intraday Margin Rule](https://docs.alpaca.markets/us/docs/the-intraday-margin-rule)
2. Equity/Order Ratio Validation Check
3. Preventing Wash Trades
4. Limit order price away sanity check

Please note that these do not apply to crypto trading as cryptocurrencies are not marginable. Preventing Wash Trades does apply to crypto trading.

# Equity/Order Ratio Validation Check

In order to help Alpaca Brokerage Account customers from placing orders larger than the calculated buying power, Alpaca has instituted a control on the account independent of the buying power for the account. Alpaca will restrict the account to closing transactions when an account has a position that is 600% larger than the equity in the account. The account will remain restricted for closing transactions until a member of Alpaca’s trading team reviews the account. The trading team will either clear the alert by allowing opening transactions or will notify the client of the restriction and take corrective actions as necessary.

# Preventing Wash Trades at Alpaca

At Alpaca, we want to help our customers avoid making unintentional wash trades. A wash trade happens when a customer buys and sells the same security at the same time, which can be seen as a form of market manipulation. To prevent this, the Alpaca Trading platform checks for potential wash trades every time a customer places an order. If we detect a possible wash trade, we reject the order and send back an error message with the HTTP status code 403 (Forbidden).

## The Rule

A wash trade occurs when a customer's two orders could potentially interact with each other. Here are a couple of examples:

* A customer places an order to buy 1 share at $10 (a limit order). Then, the same customer places an order to sell 100 shares at $10 (another limit order). These orders could potentially interact, which would be a wash trade.

* A customer places an order to sell 100 shares at the market open (a market order). Then, the same customer places an order to buy 100 shares at $10 (a limit order). Again, these orders could potentially interact, which would be a wash trade.

## How Alpaca Handles Potential Wash Trades

The Alpaca Trading platform is always on the lookout for potential wash trades. If we determine that an order could result in a wash trade, we trigger our protection measures, reject the order, and send back an error message with the HTTP status code 403 (Forbidden).

If a customer wants to set up a 'take profit' and a 'stop loss' situation, we recommend using a bracket or OCO (One Cancels the Other) order. These complex orders and trailing stop orders are exceptions to our wash trade protection.

Here's a table that shows when we would reject an order to prevent a potential wash trade:

| Existing Order   | New Order        | Reject Condition                                |
| ---------------- | ---------------- | ----------------------------------------------- |
| market buy       | market sell      | always rejected                                 |
| market buy       | limit sell       | always rejected                                 |
| market buy       | stop sell        | always rejected                                 |
| market buy       | stop\_limit sell | always rejected                                 |
| market sell      | market buy       | always rejected                                 |
| market sell      | limit buy        | always rejected                                 |
| market sell      | stop buy         | always rejected                                 |
| market sell      | stop\_limit buy  | always rejected                                 |
| stop buy         | market sell      | always rejected                                 |
| stop buy         | limit sell       | always rejected                                 |
| stop buy         | stop sell        | always rejected                                 |
| stop buy         | stop\_limit sell | always rejected                                 |
| stop sell        | market buy       | always rejected                                 |
| stop sell        | limit buy        | always rejected                                 |
| stop sell        | stop buy         | always rejected                                 |
| stop sell        | stop\_limit buy  | always rejected                                 |
| limit buy        | market sell      | always rejected                                 |
| limit buy        | limit sell       | rejected if buy limit price >= sell limit price |
| limit buy        | stop sell        | always rejected                                 |
| limit buy        | stop\_limit sell | rejected if buy limit price >= sell limit price |
| limit sell       | market buy       | always rejected                                 |
| limit sell       | limit buy        | rejected if buy limit price >= sell limit price |
| limit sell       | stop buy         | always rejected                                 |
| limit sell       | stop\_limit buy  | rejected if buy limit price >= sell limit price |
| stop\_limit buy  | market sell      | always rejected                                 |
| stop\_limit buy  | limit sell       | rejected if buy limit price >= sell limit price |
| stop\_limit buy  | stop sell        | always rejected                                 |
| stop\_limit buy  | stop\_limit sell | rejected if buy limit price >= sell limit price |
| stop\_limit sell | market buy       | always rejected                                 |
| stop\_limit sell | limit buy        | rejected if buy limit price >= sell limit price |
| stop\_limit sell | stop buy         | always rejected                                 |
| stop\_limit sell | stop\_limit buy  | rejected if buy limit price >= sell limit price |

## Paper Trading

Our wash trade protection also applies to your paper trading account. We recommend testing your trading algorithm with a realistic balance amount. This way, you can make sure your strategy works under our wash trade protection rules before you start live trading.

For more details of wash trade rule, please read<br />[FINRA's self-trades requirements](https://www.finra.org/rules-guidance/rulebooks/finra-rules/5210).