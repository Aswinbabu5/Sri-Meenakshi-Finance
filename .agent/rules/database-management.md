# Rule: Database Management

## Scope
Local SQLite (`sqflite`) schemas, migrations, indices, and backend MySQL synchronization.

## Rules
1. **Local Tables Schema**:
   - `users`: `id`, `username`, `password`, `name`, `role`.
   - `lines`: `id`, `lineCode`, `name`, `collectionDay`.
   - `customers`: `id`, `name`, `phoneNumber`, `address`, `aadharNumber`, `photoPath`, `lineCode`.
   - `loans`: `id`, `bondNumber`, `customerId`, `loanAmount`, `interestAmount`, `documentCharge`, `dailyDueAmount`, `totalAmount`, `balanceAmount`, `startDate`, `endDate`, `status`, `financialYear`.
   - `collections`: `id`, `loanId`, `bondNumber`, `amount`, `collectionDate`, `previousBalance`, `currentBalance`, `paymentMode`, `collectorId`.
2. **Web SQLite Compatibility**:
   - Web builds require initializing `databaseFactory = databaseFactoryFfiWebNoWebWorker;` in `main.dart`.
3. **Transaction Safety**:
   - Use DB transactions (`db.transaction((txn) async { ... })`) whenever creating a loan or inserting a collection record that updates loan balances.
4. **Schema Migrations**:
   - Never drop existing user production databases; increment database version and apply `ALTER TABLE` in `onUpgrade`.
