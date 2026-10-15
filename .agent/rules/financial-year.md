# Rule: Financial Year Management

## Scope
Multi-year operations, fiscal periods, and year-over-year balance roll-overs.

## Rules
1. **Fiscal Period Definition**:
   - Standard Indian Financial Year cycle: April 1st to March 31st (e.g., `2024-2025`, `2025-2026`).
2. **Mandatory Selection Upon Login**:
   - After authentication, the user selects their active working Financial Year via `FinancialYearSelectionPage`.
3. **Data Partitioning**:
   - Loans and collections belong to the active financial year selected in `LoanRepository.selectedFinancialYear`.
   - Modifying data in one financial year must never corrupt previous fiscal balances or closed books.
4. **Carry-Forward Support**:
   - Outstanding balances at year-end roll forward as opening balances in the subsequent financial year with clean reference pointers.
