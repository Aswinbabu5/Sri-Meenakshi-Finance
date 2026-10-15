# Rule: Project Architecture

## Scope
Defines the two-tier structure, technology constraints, and directory responsibilities of the `loan_management_system`.

## Rules
1. **Repository Layout**:
   - `mobile_loan_app/`: Cross-platform Flutter application (iOS, Android, Chrome/Web, macOS).
   - `backend/`: .NET 8 ASP.NET Core Web API following Clean Architecture (`Domain`, `Application`, `Infrastructure`, `API`).
   - Root: Shared configurations, build scripts (`install_on_iphone.sh`), and documentation (`PROJECT_CONTEXT.md`).
2. **Offline-First Frontend**:
   - The Flutter app must function independently offline using local SQLite (`sqflite` on native mobile, `sqflite_common_ffi_web` on web).
   - Core repository logic resides in `lib/core/services/loan_repository.dart` and `database_helper.dart`.
3. **Clean Separation of Concerns**:
   - UI widgets must not execute direct SQL or mutating queries; all requests flow through `LoanRepository` or dedicated feature controllers.
   - Domain business rules (bond validation, due generation, balance decrements) must live in core services, not inline in widget click listeners.
4. **Platform Consistency**:
   - Any dependency added to `pubspec.yaml` must support both mobile platforms (iOS/Android) and Web/Wasm environments.
