Source URL: https://docs.alpaca.markets/us/docs/the-intraday-margin-rule
Fetched: 2026-11-10 (curl, Markdown export of the ReadMe docs page)
Capture note: verbatim page text; images not captured.

---

---
updatedAt: 2026-07-07T14:18:36.000Z
agentTools:
  siteIndex: https://docs.alpaca.markets/llms.txt
  projectIndex: https://docs.alpaca.markets/us/llms.txt
---

# The Intraday Margin Rule

### **Q: What is the Intraday Margin Rule?**

The Intraday Margin Rule is a FINRA-mandated framework that replaces the legacy Pattern Day Trader (PDT) system. The rule shifts the regulatory focus from **trade frequency** (counting transactions) to **real-time risk exposure** (measuring actual financial risk during the trading day).

### **Q: Has the Pattern Day Trader (PDT) designation been removed?**

Yes. The definition of a "pattern day trader" has been eliminated. Brokers are no longer required to track "round-trip" counts or restrict accounts that execute more than three day trades in a five-day period.

### **Q: Is the $25,000 minimum equity requirement still in effect?**

No. The specific $25,000 equity minimum required to day trade has been removed. Standard Regulation T requirements still apply; for example, margin-enabled accounts typically require a minimum of $2,000 in equity to maintain intraday debits or short positions.

## **Rule Comparison**

***

| Feature                | Legacy PDT Rule                          | New Intraday Margin Rule                            |
| :--------------------- | :--------------------------------------- | :-------------------------------------------------- |
| **Trade Limits**       | Max 3 day trades per 5 days (under $25k) | **Unlimited day trades**                            |
| **Buying Power**       | Fixed (based on previous day's close)    | **Dynamic** (updates in real-time)                  |
| **Equity Calculation** | Limited to brokerage assets              | Includes **FDIC bank sweeps** & same-day deposits   |
| **Profit Treatment**   | Intraday gains ignored for buying power  | **Intraday P\&L** factored into margin availability |

## **Risk Measurement & Definitions**

***

**Q: How is intraday risk calculated under the new rule?**

Risk is monitored via three primary metrics:

* **Intraday Margin Level (IML):** A running balance of your account’s maintenance margin excess or deficit, updated continuously based on transaction activity.
* **IML-Reducing Transaction:** Any action that lowers your IML, such as purchasing securities, shorting options, or withdrawing funds.
* **Intraday Margin Deficit (IMD):** The peak negative margin deficiency recorded immediately following an IML-reducing transaction at any point during the trading day.

## **Deficits and Restrictions**

### ---

**Q: What happens if an account incurs an Intraday Margin Deficit (IMD)?**

If an IMD occurs, a margin call will be issued. This call must be satisfied within **two business days**. If an IMD remains unmet by the close of the fifth business day, the account will be subject to a **90-day freeze**, restricting the account from increasing short positions or creating new debit balances.

### **Q: Are there "De Minimis" exceptions to the new rule?**

Yes. An intraday margin call is generally not triggered if the unmet deficit is less than **$1,000 or 5% of account equity** (whichever is lower)

## **Key Benefits for Traders**

***

* **Real-Time Capital Access:** Unlike the old rule, which ignored intraday gains, the new rule allows you to use realized and unrealized intraday profits to increase your margin availability immediately.
* **Collateral Flexibility:** You can now count FDIC-insured bank sweeps and net deposits made on the same day toward your equity, providing a more accurate and favorable picture of your account's health.
* **Reduced Administrative Friction:** The removal of "counting" eliminates the risk of accidental account flags and the 90-day "PDT lock" that previously frustrated active traders.
* **Capital Efficiency:** Traders with less than $25,000 are no longer sidelined; capital can be reallocated as many times as necessary, provided the risk (IML) remains within manageable bounds.

**Margin trading involves significant risk and is not suitable for all investors.** Before considering a margin loan, it is crucial that you carefully consider how borrowing fits with your investment objectives and risk tolerance.

*When trading on margin, you assume higher market risk, and potential losses can exceed the collateral value in your account. Alpaca may sell any securities in your account, without prior notice, to satisfy a margin call. Alpaca may also change its “house” maintenance margin requirements at any time without advance written notice. You are not entitled to an extension of time on a margin call. Please review the Firm’s [Margin Disclosure Statement](https://files.alpaca.markets/disclosures/library/MarginDiscStmt.pdf) before investing.*