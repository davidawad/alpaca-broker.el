Source URL: https://docs.alpaca.markets/us/docs/understanding-finras-new-intraday-margin-rule-and-the-end-of-pdt
Fetched: 2026-11-10 (curl, Markdown export of the ReadMe docs page)
Capture note: verbatim page text; images not captured.

---

---
updatedAt: 2026-04-27T19:36:31.000Z
agentTools:
  siteIndex: https://docs.alpaca.markets/llms.txt
  projectIndex: https://docs.alpaca.markets/us/llms.txt
---

# Understanding FINRA’s New Intraday Margin Rule and the End of PDT

<br />

### **1. Introduction to the Regulatory Shift**

The Financial Industry Regulatory Authority (FINRA) has approved a comprehensive overhaul of Rule 4210, marking a fundamental pivot in the governance of active retail trading. As part of the "FINRA Forward" initiative to modernize oversight and adapt to technological advancements, the legacy Pattern Day Trading (PDT) framework is being replaced with a modern "intraday margin" system.

The primary objective of this transition is to move away from arbitrary trade-counting metrics toward a risk-sensitive system that accurately reflects intraday market exposure. By eliminating the $25,000 equity threshold and the "four trades in five days" rule, FINRA aims to reduce unnecessary financial burdens on smaller investors while maintaining robust risk oversight.

### **2. Rationale for Reform: The Technical Underpinnings**

The shift to an intraday margin framework is necessitated by structural changes in the financial landscape and academic evidence regarding intraday volatility:

* **Obsolescence of the $25,000 Threshold:** Originally designed to protect investors from high commission costs, the $25,000 requirement is viewed by industry participants—including firms like Charles Schwab and Morgan Stanley—as anachronistic. In the era of zero-commission trading, this barrier often forces retail investors to hold positions overnight to avoid PDT status, inadvertently increasing their risk.
* **Volatility and High-Frequency Risk:** Academic research (Cotter & Longin) demonstrates that daily closing prices often neglect the dynamics investors face during the trading day. High-frequency data suggests that risk levels during intraday volatility can be 50% higher than what daily data implies. The new rule addresses this by focusing on real-time maintenance margin excess.
* **Dynamic Price Discovery:** As noted by David Russell (TradeStation), active trading provides essential liquidity and enables "dynamic price discovery in lesser-known or emerging securities." The new rule acknowledges that "one man’s speculation is another man’s liquidity."
* **Capturing Modern Risks (0DTE Options):** The legacy PDT rule failed to effectively capture the risks of "Zero Day to Expiration" (0DTE) options. Under the new framework, the expiration of a long option is explicitly classified as an IML-reducing transaction, ensuring these instruments are properly margined. PM

### **3. Key Definitions: Foundations of Intraday Margin**

The new regulatory framework relies on three technical definitions to determine compliance:

* **Intraday Margin Level (IML):** The running balance of an account’s maintenance margin excess or deficit during the day, defined by a dual-pronged approach:
  * (A) The amount of cash a customer could withdraw while maintaining the required margin; or
  * (B) The amount of additional cash (expressed as a negative number) the customer would need to deposit to satisfy maintenance margin requirements.
* **IML-Reducing Transaction:** Any transaction that decreases the account’s IML. This includes security purchases, short sales of options, the expiration of long options, and the withdrawal of cash or securities.
* **Intraday Margin Deficit (IMD):** The largest negative IML recorded during the trading day following an IML-reducing transaction. Crucially, an IMD is **not** triggered by mark-to-market (market-related) losses; if a negative IML results solely from market movement rather than customer-initiated activity, it does not necessitate an IMD satisfaction.

### **4. Comparison Table: Legacy PDT Rule vs. New Intraday Margin Rule**

| *Feature*                      | *Legacy PDT Rule*                                  | *New Intraday Margin Rule*                                   |
| :----------------------------- | :------------------------------------------------- | :----------------------------------------------------------- |
| **Minimum Equity Requirement** | $25,000 for Pattern Day Traders                    | Eliminated (Standard $2,000 Reg T/Rule 4210 Minimum applies) |
| **Trade Counting**             | 4 trades in 5 days (unless \le 6% of total trades) | Eliminated; focus shifted to real-time risk exposure         |
| **Buying Power Calculation**   | Based on previous day’s close (DTBP)               | Real-time or retrospective IML calculation                   |
| **Trading into a Margin Call** | No (for PDTs)                                      | Yes                                                          |
| **Hold on Deposited Funds**    | 2-day hold required                                | None                                                         |
| **Intraday P\&L Inclusion**    | Excluded                                           | Included (by recalculating the account)                      |
| **Guaranteed Accounts**        | Prohibited for PDT requirements                    | Allowed                                                      |
| **0DTE Option Margin**         | No specific intraday requirement                   | Required; treated as IML-reducing activity                   |
| **Account Restrictions**       | 90-day "cash only" freeze for unmet calls          | 90-day freeze on *new margin debits* and *short positions*   |
| **Treatment of Bank Sweeps**   | Excluded from buying power                         | Included (requires written firm policy)                      |

### **5. Mechanics of Satisfaction and Compliance**

Firms are empowered to use real-time monitoring to block trades that would create IMDs, though retrospective end-of-day calculation is permitted.

**Satisfaction of Deficits** A customer satisfies an IMD through net deposits of cash/securities or activities that increase the account’s IML (e.g., liquidating positions to release maintenance margin).

**Timeline and Capital Charge Mitigation**

* **Prompt Satisfaction:** IMDs must be satisfied "as promptly as possible."
* **5-Day Rule:** If an IMD is not satisfied within five business days, the firm must take a capital charge starting on the 6th business day.
* **Expiration:** The capital charge is capped at 10 days because the deficit itself expires for capital purposes after 15 business days.

**The "Freeze" Protocol** If a customer fails to meet an IMD within five days and demonstrates a practice of such failures, a 90-day restriction is triggered:

* **Scope:** The customer is prohibited from creating **new debits** or **short positions** (closing existing short positions is permitted).
* **De Minimis Exceptions:** Restrictions are waived if the IMD is less than $1,000 or less than 5% of account equity.

### **6. Portfolio Margin (PM) and Special Cases**

The intraday margin requirements are modified for Portfolio Margin accounts to reflect their unique risk profiles:

* **Equity Thresholds:** The intraday margin requirement does **not** apply to PM accounts with **$5 million or more in equity**, provided the firm has the technological capability to monitor intraday risk.
* **Standard PM Accounts:** PM accounts with less than $5 million in equity must maintain margin for intraday risk that is substantially similar to the margin required for end-of-day positions.
* **Bank Sweep Integration:** To mitigate unnecessary deficiencies, firms may include FDIC-insured bank sweep balances as credit balances, provided they maintain a **written policy** for this treatment.
* **"As of" Transactions:** Firms may allocate "as of" trades to the time of processing or the actual occurrence time, provided this procedure is designed for accuracy and not for the sole purpose of reducing margin requirements.

### **7. Implementation Timeline**

FINRA recognizes the need for firms to update technological infrastructure and internal risk oversight programs.

* **Effective Date & Interim Period:** Following SEC approval, a 12-month interim transition period will commence.
* **Transition Strategy:** During this 12-month window, member firms may apply either the legacy PDT rules or the new intraday margin rules (by account or across the firm) as they transition their systems.

**Margin trading involves significant risk and is not suitable for all investors.** Before considering a margin loan, it is crucial that you carefully consider how borrowing fits with your investment objectives and risk tolerance.

*When trading on margin, you assume higher market risk, and potential losses can exceed the collateral value in your account. Alpaca may sell any securities in your account, without prior notice, to satisfy a margin call. Alpaca may also change its “house” maintenance margin requirements at any time without advance written notice. You are not entitled to an extension of time on a margin call. Please review the Firm’s [Margin Disclosure Statement](https://files.alpaca.markets/disclosures/library/MarginDiscStmt.pdf) before investing.*

<br />