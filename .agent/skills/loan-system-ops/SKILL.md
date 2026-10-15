---
name: loan-system-ops
description: >-
  Operations runbook for Sri Meenakshi Finance loan management system.
  Use when creating loans, recording daily collections, validating ledger arithmetic,
  generating scheme analytics, or running hot-reloads on Flutter web/mobile.
---

# Loan System Operations Runbook

## 1. Quick File Map
- **Daily Collections & Gpay**: `lib/features/collections/presentation/daily_collection_page.dart`
- **Loan Entry**: `lib/features/loans/presentation/loan_form_page.dart`
- **Ledger Analytics & Account Breakdown**: `lib/features/reports/presentation/widgets/ledger_analytics_widget.dart`
- **Owner Capital**: `lib/features/loans/presentation/owner_capital_page.dart`
- **Core Repository**: `lib/core/services/loan_repository.dart`
- **Database Helper**: `lib/core/services/database_helper.dart`

## 2. Fast Verification Command
```bash
export PATH="/opt/homebrew/share/flutter/bin:/opt/homebrew/bin:$PATH"
flutter analyze lib/features/collections/presentation/daily_collection_page.dart
```

## 3. Reload App
Send input `r` (hot reload) or `R` (hot restart) to `task-548` using `manage_task`.
