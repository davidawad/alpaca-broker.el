Source URL: https://docs.alpaca.markets/docs/account-plans
Fetched: 2026-11-10 (curl, Markdown export of the ReadMe docs page)
Capture note: verbatim page text; images not captured.

---

---
updatedAt: 2026-07-07T13:43:35.000Z
agentTools:
  siteIndex: https://docs.alpaca.markets/llms.txt
  projectIndex: https://docs.alpaca.markets/us/llms.txt
---

# Trading Account

# Alpaca Brokerage Account (Live Trading)

After creating an Alpaca Paper Only Account, you can enable live trading by becoming an Alpaca Brokerage Account holder. This requires you to go through an account on-boarding process with Alpaca Securities LLC, a FINRA member and SEC registered broker-dealer. We now support brokerage accounts for individuals and business entities from around the world.

With a brokerage account, you will be able to fully utilize Alpaca for your automated trading and investing needs. Using the Alpaca API, you’ll be able to buy and sell stocks in your brokerage account, and you’ll receive real-time consolidated market data. In addition, you will continue to be able to test your strategies and simulate your trades in our paper trading environment. And with the Alpaca web dashboard, it’s easy to monitor both your paper trading and your real money brokerage account. All accounts are opened as margin accounts. Accounts with $2,000 or more equity will have access to margin trading and short selling.

## Individuals

Alpaca Securities LLC supports individual taxable brokerage accounts. At this time, we do not support retirement accounts.

## Businesses/Incorporated Entities

You can open a  business trading account to use Alpaca for trading purposes, but not for building apps/services.

<Callout icon="👀" theme="default">
  ### Alpaca currently accepts entities that are _Corporations_, _LLCs_ and _Partnerships_ in the U.S., and around the world. There is a $30,000 minimum deposit required for opening a business account at Alpaca.
</Callout>

# Markets Supported

Currently, Alpaca only supports trading of listed U.S. stocks and select cryptocurrencies.

# The Account Object

The account API serves important information related to an account, including account status, funds available for trade, funds available for withdrawal, and various flags relevant to an account’s ability to trade. An account maybe be blocked for just for trades (`trading_blocked` flag) or for both trades and transfers (`account_blocked` flag) if Alpaca identifies the account to be engaging in any suspicious activity.

Please note that cryptocurrencies are not eligible assets to be used as collateral for margin accounts and will require the asset be traded using cash only.

## Sample Object

```json
{
  "account_blocked": false,
  "account_number": "010203ABCD",
  "buying_power": "262113.632",
  "cash": "-23140.2",
  "created_at": "2019-06-12T22:47:07.99658Z",
  "currency": "USD",
  "crypto_status": "ACTIVE",
  "non_marginable_buying_power": "7386.56",
  "accrued_fees": "0",
  "pending_transfer_in": "0",
  "pending_transfer_out": "0",
  "equity": "103820.56",
  "id": "e6fe16f3-64a4-4921-8928-cadf02f92f98",
  "initial_margin": "63480.38",
  "last_equity": "103529.24",
  "last_maintenance_margin": "38000.832",
  "long_market_value": "126960.76",
  "maintenance_margin": "38088.228",
  "multiplier": "4",
  "portfolio_value": "103820.56",
  "regt_buying_power": "80680.36",
  "short_market_value": "0",
  "shorting_enabled": true,
  "sma": "0",
  "status": "ACTIVE",
  "trade_suspended_by_user": false,
  "trading_blocked": false,
  "transfers_blocked": false
}
```

## Account Properties

<Table align={["left","left","left"]}>
  <thead>
    <tr>
      <th>
        Attribute
      </th>

      <th>
        Type
      </th>

      <th>
        Description
      </th>
    </tr>
  </thead>

  <tbody>
    <tr>
      <td>
        `id`
      </td>

      <td>
        string`<uuid>`
      </td>

      <td>
        Account ID.
      </td>
    </tr>

    <tr>
      <td>
        `account_number`
      </td>

      <td>
        string
      </td>

      <td>
        Account number.
      </td>
    </tr>

    <tr>
      <td>
        `status`
      </td>

      <td>
        string\<account_status>
      </td>

      <td>
        See detailed account statuses below
      </td>
    </tr>

    <tr>
      <td>
        `crypto_status`
      </td>

      <td>
        string\<account_status>
      </td>

      <td>
        The current status of the crypto enablement. See detailed crypto statuses below.
      </td>
    </tr>

    <tr>
      <td>
        `currency`
      </td>

      <td>
        string
      </td>

      <td>
        "USD"
      </td>
    </tr>

    <tr>
      <td>
        `cash`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Cash balance
      </td>
    </tr>

    <tr>
      <td>
        `portfolio_value`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        * _lpaca Broker_* Total value of cash + holding positions (Equivalent to the equity field)
      </td>
    </tr>

    <tr>
      <td>
        `non_marginable_buying_power`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Current available non-margin dollar buying power
      </td>
    </tr>

    <tr>
      <td>
        `accrued_fees`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        The fees collected.
      </td>
    </tr>

    <tr>
      <td>
        `pending_transfer_in`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Cash pending transfer in.
      </td>
    </tr>

    <tr>
      <td>
        `pending_transfer_out`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Cash pending transfer out
      </td>
    </tr>

    <tr>
      <td>
        `trade_suspended_by_user`
      </td>

      <td>
        boolean
      </td>

      <td>
        User setting. If `true`, the account is not allowed to place orders.
      </td>
    </tr>

    <tr>
      <td>
        `trading_blocked`
      </td>

      <td>
        boolean
      </td>

      <td>
        If `true`, the account is not allowed to place orders.
      </td>
    </tr>

    <tr>
      <td>
        `transfers_blocked`
      </td>

      <td>
        boolean
      </td>

      <td>
        If `true`, the account is not allowed to request money transfers.
      </td>
    </tr>

    <tr>
      <td>
        `account_blocked`
      </td>

      <td>
        boolean
      </td>

      <td>
        If `true`, the account activity by user is prohibited.
      </td>
    </tr>

    <tr>
      <td>
        `created_at`
      </td>

      <td>
        string`<timestamp>`
      </td>

      <td>
        Timestamp this account was created at
      </td>
    </tr>

    <tr>
      <td>
        `shorting_enabled`
      </td>

      <td>
        boolean
      </td>

      <td>
        Flag to denote whether or not the account is permitted to short
      </td>
    </tr>

    <tr>
      <td>
        `long_market_value`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Real-time MtM value of all long positions held in the account
      </td>
    </tr>

    <tr>
      <td>
        `short_market_value`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Real-time MtM value of all short positions held in the account
      </td>
    </tr>

    <tr>
      <td>
        `equity`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        `cash` + `long_market_value` + `short_market_value`
      </td>
    </tr>

    <tr>
      <td>
        `last_equity`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Equity as of previous trading day at 16:00:00 ET
      </td>
    </tr>

    <tr>
      <td>
        `multiplier`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Buying power (BP) multiplier that represents account margin classification

        Valid values:

        * **1** (standard limited margin account with 1x BP),
        * **2** (reg T margin account with 2x intraday and overnight BP; this is the default for all accounts with $2,000 or more equity),
        * **4** (accounts with 4x intraday BP and 2x reg T overnight BP)
      </td>
    </tr>

    <tr>
      <td>
        `buying_power`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Current available $ buying power; If multiplier = 4, this is your intraday buying power which is calculated as (last_equity - (last) maintenance_margin)_ 4; If multiplier = 2, buying_power = max(equity – initial_margin,0)_ 2; If multiplier = 1, buying_power = cash
      </td>
    </tr>

    <tr>
      <td>
        `initial_margin`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Reg T initial margin requirement (continuously updated value)
      </td>
    </tr>

    <tr>
      <td>
        `maintenance_margin`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Maintenance margin requirement (continuously updated value)
      </td>
    </tr>

    <tr>
      <td>
        `sma`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Value of special memorandum account (will be used at a later date to provide additional buying_power)
      </td>
    </tr>

    <tr>
      <td>
        `last_maintenance_margin`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Your maintenance margin requirement on the previous trading day
      </td>
    </tr>

    <tr>
      <td>
        `regt_buying_power`
      </td>

      <td>
        string`<number>`
      </td>

      <td>
        Your buying power under Regulation T (your excess equity - equity minus margin value - times your margin multiplier)
      </td>
    </tr>
  </tbody>
</Table>

# Account Status ENUMS

The following are the possible account status values. Most likely, the account status is `ACTIVE` unless there is an issue. The account status may get to `ACCOUNT_UPDATED` when personal information is being updated from the dashboard, in which case you may not be allowed trading for a short period of time until the change is approved.

| status              | description                                                |
| :------------------ | :--------------------------------------------------------- |
| `ONBOARDING`        | The account is onboarding.                                 |
| `SUBMISSION_FAILED` | The account application submission failed for some reason. |
| `SUBMITTED`         | The account application has been submitted for review.     |
| `ACCOUNT_UPDATED`   | The account information is being updated.                  |
| `APPROVAL_PENDING`  | The final account approval is pending.                     |
| `ACTIVE`            | The account is active for trading.                         |
| `REJECTED`          | The account application has been rejected.                 |