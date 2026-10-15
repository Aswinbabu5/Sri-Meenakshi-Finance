# Rule: Single-Role Admin Architecture

## Scope
Security and access control for Sri Meenakshi Finance.

## Roles
- **Admin (`admin`)**: Sole user and system owner. All operations, collections, loans, reports, edits, deletions, and database backup/restore are directly available to Admin.
- **Lender / Viewer**: Removed permanently from the system.

## Rules
1. **Single User Persona**:
   - The app only permits authentication as `admin`.
   - All role-switchers, lender tabs, and lender-restricted dialogs have been eliminated.
2. **Direct Capability Access**:
   - `LoanFormPage`: Create new loans without restriction.
   - `DailyCollectionPage`: Record daily collections without restriction.
   - `DatabaseBackupPage`: Full backup creation and restoration.
   - `EditingPage`: Full member corrections and financial term updates.
   - All navigation tabs and dashboard tiles are permanently active and vibrant.
