# Rule: Loan Management & Bond Numbering

## Scope
Creation, lifecycle, line assignments, and status transitions for loan accounts.

## Rules
1. **Line System**:
   - Four primary active lines: `Line A`, `Line B`, `Line C`, `Line D`.
   - Each loan belongs strictly to one Line at a given time.
2. **Bond Number Format**:
   - Bond format: `<LineCode>-<Number>` (e.g. `A-001`, `A-012`, `B-042`).
   - When searching, support flexible input:
     - Full bond (`A-001`), prefix bond (`A001`), or digits alone with the selected line active (`001` in Line A).
3. **Loan Status Lifecycle**:
   - `active`: Balance > 0.
   - `closed` / `settled`: Balance == 0.
   - `overdue`: Tenure expired while Balance > 0.
4. **Member Proof & Assets**:
   - Support capturing customer photo and identity proof (Aadhaar/Ration card).
   - Display proofs safely in modal viewers with placeholder fallback if image path is unavailable.
