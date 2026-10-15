# Sri Meenakshi Finance - Core Agent Rules & Memory

> **System Memory**: This repository is a bilingual (Tamil & English) micro-finance and daily/weekly loan management system (Sri Meenakshi Finance).
> **Client**: Flutter (`mobile_loan_app/`), offline-first with SQLite.
> **Backend**: .NET 8 ASP.NET Core Web API (`backend/`).
> **Domain**: Daily/weekly installment loans, partitioned into Lines (A, B, C, D), standardized bond numbers (`A-001`, `B-042`), daily collection sheets, digital passbooks, and owner capital analytics.

## Always Active Principles
1. **Never Re-Analyze From Scratch**: Read `.agent/rules/` and `PROJECT_CONTEXT.md` for existing architectural decisions, patterns, and schema contracts.
2. **Strict Financial Precision**: All balances, installment amounts, and calculations must use exact double/integer arithmetic without rounding divergence.
3. **Role Enforcement**:
   - `Admin Only`: The system operates strictly under a single persona (`admin`). Full permissions across all features (create loans, collect money, edit records, delete items, view capital, manage backups). The `Lender` role and all restricted lender access have been permanently removed.
4. **Bilingual Requirement**: Keep Tamil (`isTamil`) and English strings consistent.
5. **Flutter Hot Reload**: After modifying any file in `mobile_loan_app/lib/`, verify with `flutter analyze` and send hot reload/restart.
