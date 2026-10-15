# Rule: Testing & Validation

## Scope
Unit, widget, and integration testing for financial calculation accuracy.

## Rules
1. **Mathematical Validation Tests**:
   - Every financial formula in `LoanRepository` (due calculations, loan amount vs interest, balance decrements) must have regression coverage.
2. **Role Authorization Tests**:
   - Tests must verify that a Lender session attempting to create a loan or record collections throws an access denial exception.
3. **Database CRUD Tests**:
   - Verify that inserts into `collections` update the corresponding `loans` balance row atomically.
4. **Widget Smoke Tests**:
   - Ensure `DashboardPage`, `LoanFormPage`, and `DailyCollectionPage` mount without unbounded RenderFlex exceptions or overflow errors.
