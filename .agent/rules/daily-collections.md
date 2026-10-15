# Rule: Daily Collections Workflow

## Scope
Daily field collections, speed optimizations, payment modes, and sheet registers in `DailyCollectionPage`.

## Rules
1. **Speed Workflow & Auto-Advance**:
   - Collectors need minimal taps: Bond No -> Auto-populated Due Amount -> Click "Save & Next" (`அடுத்தது`) -> Automatically increments bond or focuses search field for rapid entry.
2. **Payment Mode Naming & State**:
   - Primary options: **`Cash`** (`ரொக்கம் (Cash)`) and **`Gpay`** (`Gpay`).
   - The label for online UPI transactions must be **`Gpay`**, NOT generic "Online" or "Net Banking".
   - When `Gpay` is selected, `isOnline` is marked `true`, automatically updating daily Gpay counters.
3. **Daily Collection Sheet (`இன்றைய பட்டியல்`)**:
   - Directly visible below the collection summary card (`மொத்த நபர்கள்`, `மொத்த வசூல்`).
   - Do NOT introduce an extraneous ledger tab in the daily collection view unless explicitly requested by the user.
4. **Immediate Sync with State**:
   - Calling `_saveCollection` must update `_collections`, adjust loan's `balanceAmount`, refresh line summary metrics, and trigger UI notification immediately.
