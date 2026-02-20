# SnapSpend

A cross-platform receipt and expense tracking app for freelancers and small business owners, with a South African market focus (ZAR primary currency).

## Tech Stack

- **Flutter** — Cross-platform UI framework (iOS, Android, Web)
- **Firebase** — Auth, Firestore, Storage, Cloud Functions, FCM, Analytics, Crashlytics
- **Riverpod** — State management
- **Hive** — Offline-first local storage
- **Melos** — Monorepo tooling

## Monorepo Structure

```
snapspend/
  packages/
    snapspend_core/         # Shared Dart package (models, services, utils)
  apps/
    mobile/                 # Flutter app — iOS, Android, Web (user-facing)
    admin/                  # Flutter Web — admin dashboard (internal support tool)
  firebase/
    functions/              # Cloud Functions — Node.js + TypeScript
    firestore.rules
    storage.rules
  .github/
    workflows/
      ci.yml
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.22.0
- [Node.js](https://nodejs.org/) >= 20
- [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools`
- [Melos](https://melos.invertase.dev/): `dart pub global activate melos`

### Setup

1. **Clone the repo and bootstrap the monorepo:**
   ```bash
   git clone <repo-url>
   cd snapspend
   melos bootstrap
   ```

2. **Add Firebase config files** — see `FIREBASE_SETUP.md` for required files.

3. **Install Cloud Functions dependencies:**
   ```bash
   cd firebase/functions && npm install
   ```

4. **Run the mobile app:**
   ```bash
   cd apps/mobile && flutter run
   ```

5. **Run the admin web app:**
   ```bash
   cd apps/admin && flutter run -d chrome
   ```

### Useful Melos Commands

```bash
melos test:all        # Run all tests
melos build:mobile    # Build mobile APK
melos build:admin     # Build admin web
```

### Running Firebase Emulators

```bash
cd firebase/functions
npm run serve
```

## Architecture

### snapspend_core

Shared Dart package containing:
- **Models**: `UserModel`, `TransactionModel`, `BudgetModel`, `CategoryModel`, `ReceiptModel`
- **Services**: Abstract interfaces for Firebase, OCR, Currency, Sync
- **Utils**: Currency/date formatters, validators
- **Constants**: App constants, default categories

### Mobile App (`apps/mobile`)

Offline-first Flutter app using Riverpod for state management and Hive for local persistence. Features:
- **Snap**: Capture receipts with on-device OCR (ML Kit) + Cloud Vision fallback
- **Home**: Monthly summary, budget rings, recent transactions
- **Reports**: Category breakdown, spending trends
- **Settings**: Profile, budget configuration, preferences

### Admin Dashboard (`apps/admin`)

Internal Flutter Web tool for support and operations:
- User management (view, search, update plan/status)
- OCR review queue (approve/correct/dismiss flagged receipts)
- KPI dashboard and revenue charts
- Billing overview

### Firebase Cloud Functions

- `processReceipt` — OCR processing on Storage upload
- `stripeWebhook` — Subscription lifecycle handling
- `budgetAlertCheck` / `invoiceReminder` — Scheduled FCM notifications
- `adminGetUser` / `adminUpdateUser` — Admin APIs
- `exportUserData` — CSV data export
- `exchangeRateSync` — Hourly FX rate updates
