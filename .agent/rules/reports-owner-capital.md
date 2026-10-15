# Rule: Reports & Owner Capital Analytics

## Scope
Ledger reporting, scheme analytics tables, owner capital statistics, and exports.

## Rules
1. **Dynamic Scheme Register Table**:
   - Dates must start from the earliest loan start date and progress sequentially day-by-day.
   - Cells show the collected amount for that specific bond on that specific calendar date.
   - Do NOT render hardcoded mock figures; only render real recorded collections.
2. **Account Breakdown Table Structure**:
   - Must appear directly below the Scheme Register in `ledger_analytics_widget.dart`.
   - Headers: `Acc No`, `Customer Name`, `Loan Amt`, `Interest Amnt`, `Document Charge`, `Total`.
   - Grand Total summary row prominently styled at the bottom.
3. **Owner Capital Metrics (`OwnerCapitalPage`)**:
   - `Total Capital Invested`: Total principal issued across all active and past loans.
   - `Total Amount Recovered`: Total collections recorded.
   - `Total Outstanding (Pending)`: Sum of all remaining balances across all active loans.
   - `Cash in Hand`: Initial capital + recovered collections - disbursed loans - expenses.
