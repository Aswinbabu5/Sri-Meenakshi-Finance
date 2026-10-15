# Rule: Financial Integrity

## Scope
Strict consistency, ledger balance verification, and precision in financial bookkeeping.

## Rules
1. **Zero-Discrepancy Ledger Rule**:
   - Every collection entry MUST immediately decrement the corresponding loan's `balanceAmount`.
   - Previous Balance (`previousBalance`) - Collected Amount (`amount`) = Closing Balance (`currentBalance`).
   - If a collection record is deleted or modified in `EditingPage`, the parent loan balance must adjust accordingly to preserve historical integrity.
2. **Double Precision & Rounding**:
   - Currency amounts must be rounded cleanly to 2 decimal places or represented without floating point accumulation errors.
   - Use `CurrencyUtils.format(amount)` for consistent Indian Rupee formatting (`₹`).
3. **No Phantom Collections**:
   - A collection record cannot be created without a valid referenced `loanId` and `bondNumber`.
   - Cannot collect an amount exceeding the remaining loan balance unless explicit penalty/interest rules are documented.
4. **Audit Trail**:
   - All collection entries must store timestamp, collector ID, line code, payment mode (`Cash` or `Online`/`Gpay`), and previous vs. new balance.
