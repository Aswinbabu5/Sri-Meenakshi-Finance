# Rule: Financial Calculations & Formulas

## Scope
Formulas for interest calculation, documentation charges, daily installment amounts, and grand totals.

## Standard Formulas
1. **Total Repayment Amount**:
   $$\text{Total Amount} = \text{Principal Loan Amount} + \text{Interest Amount}$$
2. **Disbursement Amount (In-Hand)**:
   $$\text{Net Disbursed} = \text{Principal Loan Amount} - \text{Document Charge} - \text{Advance Interest (if applicable)}$$
3. **Daily Due Amount**:
   $$\text{Daily Due} = \frac{\text{Total Amount}}{\text{Tenure Days}}$$
4. **Account Breakdown Table**:
   - Columns: `Acc No` (Bond Number), `Interest Amnt`, `Doc Charge`, `Total`.
   - **Grand Total Row**: Must calculate the aggregate sum of all columns in the active line/filter:
     - `Total Interest` = $\sum \text{Interest Amnt}$
     - `Total Document Charges` = $\sum \text{Doc Charge}$
     - `Total Overall` = $\sum \text{Total}$
5. **Scheme Register Table**:
   - Dates must generate dynamically forward from start date to present day without hardcoded date strings or fixed fake numbers.
   - For new members or fresh sessions, start clean without placeholder dummy collection amounts.
