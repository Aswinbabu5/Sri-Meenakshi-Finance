# Sri Meenakshi Finance - Loan Management System

A production-grade, bilingual (**Tamil & English**) micro-finance and daily/weekly loan management system built for financial organizations, chit collectors, and line managers. It digitizes the traditional ledger workflow (கைசிட்டை / நோட்டு வசூல்), bond tracking, passbooks, and owner capital analytics.

---

## 📌 Architecture Overview

The system consists of two primary layers:

```
loan_management_system/
├── mobile_loan_app/          # Cross-platform Client (Flutter: iOS, Android, Web, Desktop)
│   ├── lib/
│   │   ├── app/              # Theme, routes, global shell, localization
│   │   ├── core/             # SQLite DB helper, repository, models, print/PDF generator
│   │   └── features/         # Modular feature architecture
│   │       ├── auth/         # Login, role detection, Financial Year selector
│   │       ├── dashboard/    # Action grid, header, brand metadata
│   │       ├── loans/        # New loan, balance view, bond search, passbook, owner capital
│   │       ├── collections/  # Fast daily collection entry (Cash/Gpay), editing
│   │       └── reports/      # Register analytics, dynamic scheme ledger, line reports
├── backend/                  # RESTful API Backend (.NET 8 Clean Architecture)
│   ├── backend_for_loan_app.API            # ASP.NET Core Web API controllers & endpoints
│   ├── backend_for_loan_app.Application    # Core business logic, services & interfaces
│   ├── backend_for_loan_app.Domain         # Domain entities (Customer, Loan, Collection, Line)
│   └── backend_for_loan_app.Infrastructure # Entity Framework Core & MySQL / In-Memory DB
├── install_on_iphone.sh      # Automated iOS USB installation and deployment script
└── install_on_phone.sh       # Android deployment helper
```

---

## 🚀 Key Modules & Capabilities

### 1. 👥 Multi-Role & Bilingual (தமிழ் & English)
- **Roles**:
  - **நிர்வாகி (Admin)**: Full administrative access (create loans, execute collections, modify records, delete, and view financials).
  - **கடன் வழங்குநர் (Lender)**: Controlled access to view reports, customer passbooks, member details, and member corrections.
- **Instant Language Switching**: Full UI localization in both Tamil (தமிழ்) and English at the touch of a button.
- **Financial Year Isolation**: Supports switching between financial years (e.g. `2024-2025`, `2025-2026`).

### 2. 📝 Loan Creation & Bond Generation (புதிய கடன்)
- Automatic **Line assignment** (Line A, B, C, D) and standardized bond numbering (`A-001`, `B-042`, etc.).
- Calculates loan amount, interest, document charges, daily installment amount, and tenure dynamically.
- Proof/Aadhar capture and customer photo storage.

### 3. 💵 Fast Daily Collection (தினசரி வசூல்)
- Ultra-fast entry optimized for field collection agents with auto-next workflow.
- **Payment Modes**:
  - **ரொக்கம் (Cash)**
  - **Gpay** (online UPI payment tracking)
- Real-time line collection totals (`மொத்த நபர்கள்`, `மொத்த வசூல்`).
- Live customer ledger lookup and auto-tagging.

### 4. 📊 Balance View & Customer Registry (பாக்கித் தொகை)
- Live search by bond number, customer name, line, or pending status.
- Proof preview modal with identity verification details.
- Direct quick-navigation into the customer passbook.

### 5. 📖 Digital Loan Passbook (கடன் பாஸ்புக்)
- Displays chronological payment entries, previous balances, amounts received, and closing balances.
- Payment mode verification tag (`Cash` / `Gpay`).
- Print and PDF export support matching conventional chit books.

### 6. 💼 Owner Capital & Ledger Analytics (முதலாளி மூலதனம் & கடன் விபரம்)
- **Scheme Register Table**: Dynamic daily progressive columns tracking collection amounts per date from scratch without static mock numbers.
- **Account Breakdown Table**: Clear ledger listing `Acc No`, `Interest Amnt`, `Document Charge`, `Total`, and summary calculations.
- Comprehensive cash-in-hand, capital invested, total collected, and outstanding balances.

### 7. ✏️ Corrections & Editing (பிழை திருத்தம்)
- Safely update customer names, phone numbers, addresses, and line allocations without compromising ledger balance history.

---

## 🛠️ Technology Stack

| Component | Technology | Details |
|---|---|---|
| **Mobile & Web Frontend** | Flutter (Dart 3.11+) | Multi-platform (iOS, Android, Chrome/Web, macOS) |
| **Local Storage** | SQLite (`sqflite` / `sqflite_common_ffi_web`) | Offline-first database persistence |
| **State Management** | ChangeNotifier & Riverpod | Predictable reactive state synchronization |
| **Backend API** | ASP.NET Core 8 (.NET 8) | Clean Architecture with RESTful endpoints |
| **ORM & Database** | Entity Framework Core & MySQL | Resilient database with schema auto-migrations |
| **Styling & Assets** | Custom Material Theme | High contrast colors, responsive layouts, Tamil font support |

---

## 💻 Getting Started & Running the App

### Prerequisites
- Flutter SDK (3.24+ / Dart 3.5+)
- .NET 8 SDK (for backend development)
- Google Chrome (for web testing) or connected Android/iOS device

### Running the Mobile/Web App

```bash
cd mobile_loan_app

# Install Flutter dependencies
flutter pub get

# Run on Web (Chrome)
flutter run -d chrome --web-port=8080

# Run on connected Android / iOS device
flutter run
```

### Running the .NET Backend API

```bash
cd backend/backend_for_loan_app.API

# Restore and run
dotnet restore
dotnet run
```
The API Swagger/OpenAPI documentation will be accessible at `http://localhost:5000` (or configured port).

---

## 📱 iOS Deployment

To deploy the app directly to an iPhone:
```bash
./install_on_iphone.sh
```
Or open `mobile_loan_app/ios/Runner.xcworkspace` in Xcode to configure personal team signing.
