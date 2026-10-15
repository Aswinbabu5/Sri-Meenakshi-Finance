# Sri Meenakshi Finance - Mobile & Web App

This is the Flutter application for **Sri Meenakshi Finance**, supporting iOS, Android, macOS, and Web browsers.

---

## 🚀 Key Features

- **Bilingual Interface**: Native support for **தமிழ் (Tamil)** and **English**.
- **Role-Based Access**:
  - `Admin`: Full permissions (Loan creation, fast daily collections, editing, deletions, owner capital analytics).
  - `Lender`: View-only access for reports, customer passbooks, and member correction.
- **Fast Daily Collection**: Instant line-wise collection workflow with **Cash** and **Gpay** options and auto-advance.
- **Passbook & Proof Viewer**: Digital transaction history and identity proof modal.
- **Owner Capital & Scheme Analytics**: Dynamic Scheme Register table with continuous date columns, plus Account Breakdown Table with interest and documentation charges.
- **Offline-First SQLite**: Local SQLite storage running seamlessly on both native devices and web.

---

## 🏃 Running the Application

### 1. Web (Google Chrome)
```bash
flutter pub get
flutter run -d chrome --web-port=8080
```

### 2. Physical iPhone / iOS
Connect your device and run:
```bash
flutter run -d ios
```
Or use the automated helper script in the parent directory:
```bash
../install_on_iphone.sh
```

### 3. Android Device / Emulator
```bash
flutter run -d android
```

---

## 📂 Project Structure

- `lib/app/`: App entrypoint, theming, routing, and shell navigation.
- `lib/core/models/`: Data models (`LoanModel`, `CollectionModel`, `CustomerModel`, `UserModel`, `LineModel`).
- `lib/core/services/`: SQLite helper (`DatabaseHelper`), `LoanRepository`, and passbook exporter.
- `lib/features/auth/`: Login and Financial Year selection.
- `lib/features/dashboard/`: Main dashboard action tiles, header, and line stats.
- `lib/features/loans/`: New loan form, balance viewer, bond search, passbook, and owner capital.
- `lib/features/collections/`: Daily collection entry (`daily_collection_page.dart`) and corrections.
- `lib/features/reports/`: Reports and `ledger_analytics_widget.dart`.
