# Rule: Backend Development (.NET 8)

## Scope
Architecture, controllers, service dependencies, and database migrations in `backend/`.

## Rules
1. **Clean Architecture Layers**:
   - `backend_for_loan_app.Domain`: Entities only (`Loan`, `Customer`, `DailyCollection`, `CollectionLine`). No dependencies on external libraries.
   - `backend_for_loan_app.Application`: Interfaces (`IAppDbContext`), DTOs, and application business services (`LoanServices`, `CollectionServices`).
   - `backend_for_loan_app.Infrastructure`: EF Core `AppDbContext`, MySQL configurations, data seeders (`DataSeeder`).
   - `backend_for_loan_app.API`: REST Controllers, CORS policies, DI configuration, Swagger/OpenAPI setup.
2. **CORS & Multi-Platform Client Support**:
   - API must allow cross-origin requests (`AllowAll` or explicitly configured ports for Flutter web and local apps).
3. **Circular Reference Protection**:
   - `JsonSerializerOptions.ReferenceHandler` must be set to `IgnoreCycles` to prevent recursion when serializing entity navigation properties.
4. **Resilient Database Fallback**:
   - Auto-create tables with `db.Database.EnsureCreated()` and auto-seed initial administration users.
