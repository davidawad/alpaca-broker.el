Source URL: https://docs.alpaca.markets/us/docs/index-options
Fetched: 2026-11-10 (curl, Markdown export of the ReadMe docs page)
Capture note: verbatim page text; images not captured.

---

---
updatedAt: 2026-10-23T13:35:05.000Z
agentTools:
  siteIndex: https://docs.alpaca.markets/llms.txt
  projectIndex: https://docs.alpaca.markets/us/llms.txt
---

# Index Options

### What are Index Options?

Index options are contracts on the value of a market index (such as the S\&P 500 or VIX), not on individual stocks. Generally, they are cash-settled and European-style: positions settle in cash at expiration and cannot be exercised or assigned early. There is no share delivery and no early-assignment risk.

***

### How do I enable Index Options?

Contact your Customer Success Manager for pricing and the steps to enable index options. Enablement is at the correspondent and the end account. Options trading must already be approved on the account.

***

### How are index options different from equity options?

* Cash-settled: no share delivery at expiration
* European-style: exercise and assignment only at expiration; no early assignment
* AM or PM expiration: each contract settles against an official Cboe reference value (for example, SPX monthlies are AM; SPXW weeklies are PM)
* Exchange fees: Index option fees differ from equity options. Cboe proprietary fees on exclusive listings (such as SPX® and VIX®) are passed through

***

### Is there a separate Broker API for index options?

No. Index options use the same contracts, orders, positions, and activities surfaces you already use for equity options.

***

### Which index option products are supported?

| Root | Product                                | Settlement |
| ---- | -------------------------------------- | ---------- |
| SPX  | S\&P 500 monthlies                     | AM         |
| SPXW | S\&P 500 weeklies                      | PM         |
| XSP  | Mini-S\&P 500 (1/10 of SPX)            | PM         |
| VIX  | Cboe Volatility Index                  | AM         |
| VIXW | VIX Weeklies                           | AM         |
| DJX  | Dow Jones Industrial Average           | AM         |
| DJXW | Dow Jones Industrial Average weeklies  | PM         |

List and trade by the index underlier (`SPX`, `XSP`, `VIX`, `DJX`). Weekly OSI roots (SPXW, VIXW) sit under SPX and VIX; they are not separate underliers.

***

### What Order Types and Time-In-Force (TIF) are supported for index options?

* Order types: `Market`, `Limit`, `Stop` , and `Stop Limit`
* TIF: `Day` and `GTC`
* Strategies: Single-leg and same-expiration Multi-leg, subject to the account’s options level
* Not supported: IOC/FOK, trailing stop, notional, fractional contracts, extended hours, calendar/diagonal spreads

***

### Which options levels apply for index options?

The same `L1`–`L3` model as equity options:

* `L1`: cash-secured puts only (no covered calls because there is no underlying stock)
* `L2`: long calls and puts
* `L3`: same-expiration defined-risk multi-leg

***

### Are multi-leg strategies supported for index options?&#x20;

Yes, with restrictions. Vertical spreads, iron condors, butterflies, and other multi-leg strategies where all European-style legs share the same expiration date are supported. Calendar spreads (different expirations) are rejected because European-style legs in a multi-leg order must have the same expiration date.

***

### How do AM vs. PM expirations work?

* AM-settled (SPX, VIX, VIXW, DJX):&#x20;
  * Settle against the official morning Cboe reference.&#x20;
  * New orders for AM-settled contracts expiring that session are rejected after the morning cutoff.
* PM-settled (SPXW, XSP):&#x20;
  * Settle against the official 4:00 p.m. ET index close.&#x20;
  * Same-day expiring PM contracts stop trading at 4:00 p.m. ET.&#x20;
  * Longer-dated PM contracts trade until 4:15 p.m. ET.

***

### How is cash settlement calculated for index options?

For cash-difference contracts, settlement = (settlement index value − strike) × contract multiplier × quantity, floored at zero for intrinsic value.

Example: SPX Call 5000 × 100 multiplier, SET = 5032 → cash settlement = (5032 − 5000) × 100 = $3,200 credit to the long.

| Position  | Result    | **Intrinsic Calculation** | Example ($500 Strike) | Cash Impact    |
| --------- | --------- | ------------------------- | --------------------- | -------------- |
| LongCall  | Exercised | (Index - Strike)\* 100    | Index settles at $510 | $1,000(Credit) |
| ShortCall | Assigned  | (Index - Strike)\* 100    | Index settles at $510 | -$1,000(Debit) |
| LongPut   | Exercised | (Strike - Index)\* 100    | Index settles at $480 | $2,000(Credit) |
| ShortPut  | Assigned  | (Strike - Index)\* 100    | Index settles at $480 | -$2,000(Debit) |

***

### Does Alpaca support 0DTE Index Options?&#x20;

Yes.

***

### Can an account exercise or be assigned early for index options?

No. Alpaca’s initial offering is for European-style Index Options. Exercise and assignment occur only at expiration. Early exercise, Do Not Exercise (DNE), and Expire Deliverable (EED) requests are rejected.

***

### What fees apply for trading index options?&#x20;

For Broker API Partners, there are two fees on each fill to consider:

* **Alpaca trading fee:**  Per contract, by monthly volume. Additional fees apply, contact your CSM to discuss. A partner can choose whether to cover or pass to their end customers.
* **Cboe exchange fee:&#x20;**&#x20;Pass-through at Cboe’s schedule, not discounted. A partner can cover it or pass it to their end customers.

| Index Option Symbol | When                         | Fee per contract |
| ------------------- | ---------------------------- | ---------------- |
| DJX                 | Quantity executed < 10<br /> | $0.00            |
|                     | Quantity executed ≥ 10       | $0.07            |
| SPX                 | Premium < $1                 | $0.57            |
|                     | Premium ≥ $1                 | $0.66            |
| SPXW                | Premium < $1                 | $0.50            |
|                     | Premium ≥ $1                 | $0.59            |
| XSP                 | Quantity executed < 10       | $0.00            |
|                     | Quantity executed ≥ 10       | $0.07            |
| VIX/VIXW            | Premium ≤ $0.10              | $0.10            |
|                     | Premium $0.11 - $0.99        | $0.25            |
|                     | Premium $0.11 - $0.99        | $0.40            |
|                     | Premium ≥ $2                 | $0.45            |

**Other considerations:**

* No exercise fee.
* Multi-leg is charged per contract.

Contact your customer success manager for additional detail and review on fees and pricing.

***

### Does Alpaca provide market data for the underlying index level (spot SPX, VIX, and similar)?

Not at initial launch. Market data for index option contracts is available on the existing OPRA options feed. Market data for the underlying index level (spot SPX, VIX, and similar) is not in the initial offering.

***

### What is not supported at launch for index options?

* NDX / NQX, RUT / MRUT, OEX / XSP binary options
* American-style index options
* Calendar and diagonal spreads
* Naked / uncovered index shorts
* Index-level (spot) market data
* Extended hours / GTH for index options

***

What Broker API changes are required for trading index options?<br />No new endpoints are required. Use the existing Broker API endpoints for options contracts, orders, positions, and activities.

When listing contracts, query by underlier:

* `SPX`: includes SPX monthlies and SPXW weeklies
* `XSP`
* `VIX`: includes VIX and VIXW
* `DJX`: includes DJX and DJXW

Index contracts are European-style & cash-settled.

Fills and partial fills continue on the existing trade stream. Expiration cash (`OPCSH`), assignment, and worthless expire activity appear on activities, not the trade stream.

***

### How can I identify index option contracts via Broker API?

On Broker API, call `GET /v1/options/contracts` and set `underlying_symbols` to `SPX`, `XSP`, `VIX`, or `DJX`. That returns the option chain for those underliers, including weeklies (SPXW, VIXW). Index contracts are European-style.

***

### What are the different timings for AM- and PM-settled index options?

AM and PM index options use different timings.

1. **Last trade Time:**  The time when Alpaca stops accepting new orders for that series.
2. **Official settlement value:&#x20;**&#x20;The exchange publishes the official settlement value in the morning or evening (product dependent)&#x20;
3. **Alpaca's Activity Stream:&#x20;**&#x41;lpaca publishes stream event at expiry&#x20;
   1. `OPEXC` + `OPCSH` :  Long, cash settles. Exercise → receive cash intrinsic
   2. `OPASN` + `OPCSH`:  Short, cash settles. Assigned → pay/owe cash intrinsic
   3. No `OPCSH`: Expires worthless / no cash&#x20;
4. **Cash settle date:**  The date on the cash settlement activity (usually the next business day after expiry).&#x20;

Tables below capture additional information of AM- and PM- Index Products and their specific timelines:

* T = expiration date , the series expiry date
* Times are in Eastern Standard Times
* Exact timing on OPCSH can differ as we are dependent on OCC and CBOE dissemination of price and data files

<Table>
  <thead>
    <tr>
      <th style={{ width: "6.9%" }}>
        **Product**
      </th>

      <th style={{ width: "7.4%" }}>
        **Type**
      </th>

      <th style={{ width: "18.6%" }}>
        **Last trade (Alpaca)**
      </th>

      <th style={{ width: "25.6%" }}>
        **Exchange settlement value**
      </th>

      <th style={{ width: "21%" }}>
        **Alpaca Activity Stream**
      </th>

      <th style={{ width: "17.8%" }}>
        **Cash&#x20;**<br />**Settle Date**
      </th>
    </tr>
  </thead>

  <tbody>
    <tr>
      <td>
        SPX
      </td>

      <td>
        AM
      </td>

      <td>
        Day before expiry (T−1), through \~4:15 PM&#x20;
      </td>

      <td>
        Expiry day (T).<br /><br />Occurs in the morning and exact time varies by the exchanges opening process.
      </td>

      <td>
        Expiry day (T). <br /><br />Stream events \~10 AM–1 PM
      </td>

      <td>
        T+1
      </td>
    </tr>

    <tr>
      <td>
        VIX
      </td>

      <td>
        AM
      </td>

      <td>
        Day before expiry (T−1), through \~4:15 PM&#x20;
      </td>

      <td>
        Expiry day (T).<br /><br />Occurs in the morning and exact time varies by the exchanges opening process.
      </td>

      <td>
        Expiry day (T). <br /><br />Stream events occur \~10 AM–1 PM
      </td>

      <td>
        T+1
      </td>
    </tr>

    <tr>
      <td>
        VIXW
      </td>

      <td>
        AM
      </td>

      <td>
        Day before expiry (T−1), through \~4:15 PM&#x20;
      </td>

      <td>
        Expiry day (T).<br /><br />Occurs in the morning and exact time varies by the exchanges opening process.
      </td>

      <td>
        Expiry day (T). <br /><br />Stream events occur \~10 AM–1 PM
      </td>

      <td>
        T+1
      </td>
    </tr>

    <tr>
      <td>
        DJX
      </td>

      <td>
        AM
      </td>

      <td>
        Day before expiry (T−1), through \~4:15 PM&#x20;
      </td>

      <td>
        Expiry day (T).<br /><br />Occurs in the morning and exact time varies by the exchanges opening process.
      </td>

      <td>
        Expiry day (T). <br /><br />Stream events occur \~10 AM–1 PM
      </td>

      <td>
        T+1
      </td>
    </tr>

    <tr>
      <td>
        SPXW
      </td>

      <td>
        PM
      </td>

      <td>
        Expiry day (T); 4:00 PM if expiring that day; else \~4:15 PM
      </td>

      <td>
        Expiry day (T). <br /><br />Based on the 4 PM index close.
      </td>

      <td>
        Expiry day (T).<br /><br />Stream events occur \~9 PM.
      </td>

      <td>
        T+1
      </td>
    </tr>

    <tr>
      <td>
        XSP
      </td>

      <td>
        PM
      </td>

      <td>
        Expiry day (T); 4:00 PM if expiring that day; else \~4:15 PM
      </td>

      <td>
        Expiry day (T). <br /><br />Based on the 4 PM index close.
      </td>

      <td>
        Expiry day (T).<br /><br />Stream events occur \~9 PM.
      </td>

      <td>
        T+1
      </td>
    </tr>

    <tr>
      <td>
        DJXW
      </td>

      <td>
        PM
      </td>

      <td>
        Expiry day (T); 4:00 PM if expiring that day; else \~4:15 PM
      </td>

      <td>
        Expiry day (T). <br /><br />Based on the 4 PM index close.
      </td>

      <td>
        Expiry day (T).<br /><br />Stream events occur \~9 PM.
      </td>

      <td>
        T+1
      </td>
    </tr>
  </tbody>
</Table>

<br />

***

### How can I trade index options in my sandbox enviroment?

Please contact your Customer Success Manager to request that index options be enabled in your sandbox environment. Before index options can be enabled, your environment must already have Options enabled.<br />Once enabled, you can list index option contracts using the same contracts endpoint used for equity options and submit orders through the existing orders endpoint.