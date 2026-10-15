# Development Workflow: Sri Meenakshi Finance

## Quick Step-by-Step Flow

```mermaid
graph LR
    A[Receive Request] --> B[Check Rules & Target File]
    B --> C[Make Edit]
    C --> D[Run flutter analyze]
    D --> E[Trigger Hot Reload / Restart]
    E --> F[Respond to User]
```

### 1. Identify Target Component
- Daily collections / Gpay / Sheet -> `lib/features/collections/presentation/daily_collection_page.dart`
- New loan / forms / calculations -> `lib/features/loans/presentation/loan_form_page.dart`
- Scheme register / Ledger analytics -> `lib/features/reports/presentation/widgets/ledger_analytics_widget.dart`
- Passbook / PDF generation -> `lib/features/loans/presentation/loan_passbook_page.dart` & `passbook_service.dart`
- Capital analytics -> `lib/features/loans/presentation/owner_capital_page.dart`
- Database & Repository logic -> `lib/core/services/loan_repository.dart` & `database_helper.dart`

### 2. Apply Edits
- Keep styling aligned with `AppColors`.
- Respect bilingual logic (`isTamil ? ... : ...`).
- Respect role access (`repository.isAdmin`).

### 3. Verify & Reload
```bash
flutter analyze <modified_file_path>
```
Send `r` or `R` to task `task-548` via `manage_task`.

### 4. Report
Provide concise explanation with clickable markdown file links.
