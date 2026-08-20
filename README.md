# Ledgerly — Expense & Accounts Management

Ledgerly is a **Flutter offline-first expense and simple accounting application** designed for small businesses.

The application uses a local **SQLite database as the authoritative data store**, allowing customers, suppliers, transactions, expenses, statements, reports, and language preferences to work without an internet connection.

Google Drive integration is optional and is used only for **user-initiated backup and restore**.

---

## Features

| Feature                 | Description                                                                                                 |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Offline-First**       | Versioned SQLite database with migrations, foreign keys, indexes, repositories, transactions, and seed data |
| **Customers**           | Customer CRUD, search, balances, protected deletion, details, and running statements                        |
| **Suppliers**           | Supplier CRUD, search, balances, protected deletion, details, and running statements                        |
| **Accounting**          | Centralized debit/credit balance calculation with debtor, creditor, and settled states                      |
| **Transactions**        | Financial transaction management with running balances and statements                                       |
| **Expenses**            | Expense CRUD, categories, payment methods, dates, search, and filtering                                     |
| **Dashboard**           | Financial summaries, income/expense charts, category charts, monthly activity, and recent entries           |
| **Reports**             | Financial summary, customer/supplier balances, expense categories, transaction register, and date filters   |
| **Localization**        | Arabic RTL and English LTR with persisted language preferences                                              |
| **Local Backup**        | SQLite database backup with manifest and SHA-256 verification                                               |
| **Google Drive Backup** | Optional private application-data backup using Google Drive                                                 |
| **JSON Export/Import**  | Validated JSON data export and import                                                                       |
| **Restore Safety**      | Automatic pre-restore safety backup and SQLite integrity validation                                         |

---

## Tech Stack

* **Flutter**
* **Dart**
* **Material 3**
* **Riverpod**
* **SQLite**
* **sqflite**
* **Flutter Localization / ARB**
* **Google Sign-In**
* **Google Drive API**
* **fl_chart**
* **file_picker**
* **path_provider**
* **share_plus**

---

## Architecture

Ledgerly follows a **feature-first clean architecture**.

Database access is isolated inside repositories and services. UI widgets do not access SQLite directly; instead, application state is provided through Riverpod providers.

### Architecture Principles

* Offline-first data management
* Repository pattern
* Feature-first project structure
* Centralized accounting calculations
* Versioned SQLite schema
* Transaction-safe database operations
* Typed application errors
* Localized user interface
* Safe backup and restore workflow
* Separation between UI, state, business logic, and persistence

For the complete architecture and database design, see:

[`docs/architecture.md`](docs/architecture.md)

---

## Project Structure

```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── migrations/
│   │   └── schema/
│   │
│   ├── errors/
│   │   └── application_errors.dart
│   │
│   ├── services/
│   │   ├── accounting_service.dart
│   │   ├── backup_service.dart
│   │   ├── google_drive_service.dart
│   │   └── data_invalidation_service.dart
│   │
│   ├── models.dart
│   └── providers.dart
│
├── features/
│   ├── customers/
│   ├── suppliers/
│   ├── transactions/
│   ├── expenses/
│   ├── dashboard/
│   ├── reports/
│   ├── backup/
│   └── settings/
│
├── l10n/
│   ├── app_ar.arb
│   └── app_en.arb
│
└── shared/
    ├── responsive_shell/
    ├── theme/
    └── components/
```

---

## Offline-First Database

SQLite is the **primary and authoritative source of application data**.

The application does not require an internet connection for normal operation.

The local database contains:

* Customers
* Suppliers
* Transactions
* Expense categories
* General expenses
* Application settings
* Language preferences
* Database metadata

The database uses:

* Versioned schema
* Migrations
* Foreign keys
* Indexes
* Transactions
* Referential integrity
* Protected deletion
* Seed data for new installations

Demo data is inserted **only when a brand-new local database is created**.

---

## Accounting Convention

Ledgerly uses a single centralized accounting rule through `AccountingService`.

### Balance Formula

> **Balance = Total Debit − Total Credit**

The result is interpreted as follows:

|  Balance | State    |
| -------: | -------- |
| Positive | Debtor   |
| Negative | Creditor |
|     Zero | Settled  |

This convention is reused throughout the application, including:

* Customer cards
* Supplier cards
* Running statements
* Dashboard
* Reports
* Balance calculations

Centralizing this logic prevents different screens from calculating balances differently.

---

## Expenses

The expense module supports:

* Create expense
* Edit expense
* Delete expense
* Expense categories
* Payment methods
* Expense dates
* Search
* Category filtering
* Date filtering
* Expense summaries
* Category-based aggregation

Expense data is stored locally in SQLite and remains available offline.

---

## Dashboard

The dashboard provides an overview of the financial state of the business.

It includes:

* Total income
* Total expenses
* Net balance
* Customer count
* Supplier count
* Transaction count
* Income vs. expense chart
* Expense category chart
* Monthly activity
* Recent financial entries

Charts are implemented using `fl_chart`.

---

## Reports

Ledgerly provides several reporting views:

### Financial Summary

Provides an overview of:

* Income
* Expenses
* Net result
* Financial activity

### Customer Report

Includes:

* Customer balances
* Debtor balances
* Creditor balances
* Running statements

### Supplier Report

Includes:

* Supplier balances
* Debtor balances
* Creditor balances
* Running statements

### Expense Report

Includes:

* Total expenses
* Expense categories
* Category aggregation
* Date-based filtering

### Transaction Register

Includes:

* Transactions
* Debit
* Credit
* Dates
* Party information
* Period filtering

---

## Localization

Ledgerly supports:

* **Arabic**
* **English**

Arabic uses:

* RTL layout
* Arabic translations
* Right-to-left UI direction

English uses:

* LTR layout
* English translations
* Left-to-right UI direction

Localization strings are maintained using Flutter ARB files.

The selected language is persisted locally in SQLite, so the user's preference remains available after restarting the application.

---

## Backup & Restore

Ledgerly provides multiple backup and recovery mechanisms.

### Local SQLite Backup

A database backup is stored as a copied SQLite file, for example:

```text
backup_2026_08_17_2300.db
```

Each backup has a separate manifest containing:

* Backup format version
* Backup timestamp
* Database schema version
* SHA-256 hash
* Backup file name

### Restore Safety

Before restoring a database, Ledgerly:

1. Creates an automatic local safety copy.
2. Copies the candidate database to a temporary location.
3. Validates SQLite integrity.
4. Verifies required tables.
5. Closes active database resources.
6. Replaces the active database.
7. Restores the previous database if replacement fails.

This prevents a corrupted or invalid backup from permanently replacing the current database.

---

## JSON Export & Import

Ledgerly also supports structured JSON data export and import.

The exported JSON contains:

* Customers
* Suppliers
* Transactions
* Expense categories
* General expenses
* Settings
* `databaseVersion`
* `backupTimestamp`

### Import Validation

Before importing data, Ledgerly validates:

* JSON structure
* Required fields
* Enumerations
* Date values
* Positive monetary amounts
* Database metadata
* Required data fields

All imported records are written inside a **single SQLite transaction**.

If the import fails, the transaction is rolled back.

---

## Google Drive Backup

Google Drive backup is **optional**.

The integration uses only:

```text
drive.appdata
```

This means backups are stored in the user's private application-data area instead of accessing ordinary Google Drive files.

OAuth tokens are not stored in SQLite.

### Google Cloud Setup

Before Google Drive backup can be used in a signed application:

1. Create a Google Cloud project.
2. Enable the Google Drive API.
3. Configure the OAuth consent screen.
4. Add the `drive.appdata` scope.
5. Register the Android application ID.
6. Add the required SHA-1 fingerprints.
7. Configure `google-services.json` if required by the selected Android authentication setup.
8. Configure the iOS bundle ID and URL scheme when supporting iOS.
9. Configure the web origin and web client ID when deploying to web.

The Google Drive sign-in action is available from the **Backup** screen.

Authentication errors are intentionally presented as localized setup messages instead of exposing raw provider exceptions.

> Google Drive is optional. Local SQLite backup, JSON export/import, validation, and restore functionality work without Google Drive.

---

## Installation

### Requirements

Install a current stable version of Flutter and ensure that Flutter is available in your system PATH.

Check your environment:

```bash
flutter doctor
```

Check the installed Flutter version:

```bash
flutter --version
```

### Install Dependencies

From the project root:

```bash
flutter pub get
```

### Generate Localization

```bash
flutter gen-l10n
```

### Run the Application

```bash
flutter run
```

---

## Development

Before committing changes, run static analysis:

```bash
flutter analyze --no-fatal-infos
```

Run the test suite:

```bash
flutter test
```

For a clean dependency rebuild:

```bash
flutter clean
flutter pub get
```

---

## Testing

The test suite covers important application and database behavior, including:

### Accounting

* Balance calculation
* Debit/credit interpretation
* Running statements

### Database

* SQLite initialization
* Schema creation
* Migrations
* Foreign-key behavior

### Parties

* Customer CRUD
* Supplier CRUD
* Protected deletion
* Balance retrieval

### Transactions

* Transaction creation
* Transaction updates
* Transaction retrieval
* Running statements

### Expenses

* Expense category persistence
* General expense persistence
* Filtered expense retrieval
* Search and category filtering

---

## Data Integrity

Ledgerly prioritizes local data integrity.

Important safeguards include:

* SQLite foreign keys
* Database transactions
* Protected deletion
* Schema versioning
* Migration support
* Backup manifests
* SHA-256 verification
* SQLite integrity checks
* Restore rollback
* JSON validation
* Atomic imports

---

## Design Philosophy

Ledgerly is designed around a simple principle:

> **The application should remain useful even when there is no internet connection.**

The internet is treated as an optional service rather than a requirement for normal accounting operations.

Local SQLite handles the core business data, while Google Drive provides an optional mechanism for backup and recovery.

---

## Roadmap

Potential future improvements include:

* Advanced accounting reports
* More financial statements
* Multi-business support
* Recurring expenses
* Recurring transactions
* PDF reports
* Excel export
* Cloud synchronization
* Additional backup providers
* Role-based access
* Audit logs
* Advanced dashboard analytics

---

## License

This project is currently intended for private/commercial use.

Add the appropriate license information here before publishing the project publicly.

---

## Summary

Ledgerly is a lightweight **offline-first Flutter accounting and expense management application** built for small businesses.

Its core architecture combines:

* Flutter
* Riverpod
* SQLite
* Repository-based data access
* Centralized accounting logic
* Arabic/English localization
* Local backup and restore
* JSON import/export
* Optional Google Drive backup

The application is designed to provide reliable financial data management **without requiring a permanent internet connection**.
