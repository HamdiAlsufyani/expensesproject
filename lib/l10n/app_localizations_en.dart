// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ledgerly';

  @override
  String get home => 'Home';

  @override
  String get customers => 'Customers';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get expenses => 'Expenses';

  @override
  String get transactions => 'Transactions';

  @override
  String get reports => 'Reports';

  @override
  String get backup => 'Backup';

  @override
  String get settings => 'Settings';

  @override
  String get overview => 'Financial overview';

  @override
  String get totalIncome => 'Total income';

  @override
  String get totalExpenses => 'Total expenses';

  @override
  String get customerDebit => 'Customer debit';

  @override
  String get customerCredit => 'Customer credit';

  @override
  String get supplierDebit => 'Supplier debit';

  @override
  String get supplierCredit => 'Supplier credit';

  @override
  String get netBalance => 'Net balance';

  @override
  String get customerCount => 'Customers';

  @override
  String get supplierCount => 'Suppliers';

  @override
  String get incomeVsExpenses => 'Income vs. expenses';

  @override
  String get expensesByCategory => 'Expenses by category';

  @override
  String get monthlyActivity => 'Monthly financial activity';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get addSupplier => 'Add supplier';

  @override
  String get editSupplier => 'Edit supplier';

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get email => 'Email';

  @override
  String get address => 'Address';

  @override
  String get notes => 'Notes';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get search => 'Search';

  @override
  String get noResults => 'No matching records found.';

  @override
  String get noData => 'No data available yet.';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get invalidEmail => 'Enter a valid email address.';

  @override
  String get amount => 'Amount';

  @override
  String get invalidAmount => 'Enter an amount greater than zero.';

  @override
  String get date => 'Date';

  @override
  String get description => 'Description';

  @override
  String get referenceNumber => 'Reference number';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get transactionType => 'Transaction type';

  @override
  String get party => 'Party';

  @override
  String get partyType => 'Party type';

  @override
  String get customer => 'Customer';

  @override
  String get supplier => 'Supplier';

  @override
  String get general => 'General';

  @override
  String get debit => 'Debit';

  @override
  String get credit => 'Credit';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get cash => 'Cash';

  @override
  String get bankTransfer => 'Bank transfer';

  @override
  String get card => 'Card';

  @override
  String get other => 'Other';

  @override
  String get category => 'Category';

  @override
  String get selectCategory => 'Select a category';

  @override
  String get selectParty => 'Select a party';

  @override
  String get balance => 'Balance';

  @override
  String get totalDebit => 'Total debit';

  @override
  String get totalCredit => 'Total credit';

  @override
  String get settled => 'Settled';

  @override
  String get debtor => 'Debtor';

  @override
  String get creditor => 'Creditor';

  @override
  String get statement => 'Statement';

  @override
  String get details => 'Details';

  @override
  String get dateFrom => 'From date';

  @override
  String get dateTo => 'To date';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get thisYear => 'This year';

  @override
  String get customRange => 'Custom range';

  @override
  String get allTime => 'All time';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get apply => 'Apply';

  @override
  String get financialSummary => 'Financial summary';

  @override
  String get netProfitLoss => 'Net profit / loss';

  @override
  String get customerReport => 'Customer report';

  @override
  String get supplierReport => 'Supplier report';

  @override
  String get expenseReport => 'Expense report';

  @override
  String get transactionReport => 'Transaction report';

  @override
  String get transactionCount => 'Transactions';

  @override
  String get createBackup => 'Create database backup';

  @override
  String get backupDescription =>
      'Create a complete local SQLite copy, ready for import or Drive upload.';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get importDatabase => 'Import database backup';

  @override
  String get importJson => 'Import JSON';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signInGoogle => 'Sign in with Google';

  @override
  String get uploadBackup => 'Upload backup';

  @override
  String get restoreFromDrive => 'Restore from Google Drive';

  @override
  String get availableBackups => 'Available backups';

  @override
  String get restoreWarningTitle => 'Replace current data?';

  @override
  String get restoreWarning =>
      'Restoring this backup will replace your current local data. Continue?';

  @override
  String get confirm => 'Continue';

  @override
  String get backupCreated => 'Backup created successfully.';

  @override
  String get backupUploaded => 'Backup uploaded successfully.';

  @override
  String get restoreCompleted =>
      'Data restored successfully. Restart the app to reload safely.';

  @override
  String get importCompleted => 'Import completed successfully.';

  @override
  String get exportCompleted => 'Export completed successfully.';

  @override
  String get operationFailed =>
      'We could not complete the operation. Please try again.';

  @override
  String get invalidBackup =>
      'This backup is invalid, damaged, or incompatible.';

  @override
  String get databaseProtected =>
      'Your current database was protected with an automatic safety copy.';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get appearance => 'Appearance & language';

  @override
  String get database => 'Database';

  @override
  String get seedData => 'Demo data';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'Version 1.0.0';

  @override
  String get deleteTitle => 'Delete record?';

  @override
  String get deleteMessage => 'This action cannot be undone.';

  @override
  String get recordDeleted => 'Record deleted.';

  @override
  String get recordSaved => 'Record saved.';

  @override
  String get cannotDeleteParty =>
      'This party has transactions and cannot be deleted.';

  @override
  String get viewDetails => 'View details';

  @override
  String get transactionHistory => 'Transaction history';

  @override
  String get addCategory => 'Add category';

  @override
  String get categoryName => 'Category name';

  @override
  String get filter => 'Filter';

  @override
  String get close => 'Close';

  @override
  String get download => 'Download';

  @override
  String get logout => 'Sign out';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String signedInAs(Object email) {
    return 'Signed in as $email';
  }

  @override
  String get safeRestore => 'Safe restore';

  @override
  String get safeRestoreDescription =>
      'Every restore is validated before it can replace your local ledger.';

  @override
  String get localBackup => 'Local backup';

  @override
  String get driveSetupRequired =>
      'Google Drive access requires platform OAuth setup before it can be used.';

  @override
  String get loading => 'Loading…';

  @override
  String get retry => 'Retry';

  @override
  String get selectDate => 'Select date';

  @override
  String get allCategories => 'All categories';

  @override
  String get allTypes => 'All types';

  @override
  String get allMethods => 'All payment methods';

  @override
  String get backupFile => 'Backup file';

  @override
  String get jsonFile => 'JSON file';

  @override
  String get back => 'Back';
}
