import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/customers/data/party_repository.dart';
import '../features/dashboard/data/report_repository.dart';
import '../features/expenses/data/expense_repository.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/transactions/data/transaction_repository.dart';
import 'database/app_database.dart';
import 'models.dart';
import 'services/accounting_service.dart';
import 'services/backup_service.dart';
import 'services/data_change_notifier.dart';
import 'services/google_drive_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final dataChangeProvider = NotifierProvider<DataChangeNotifier, int>(
  DataChangeNotifier.new,
);

final accountingServiceProvider = Provider<AccountingService>(
  (ref) => const AccountingService(),
);
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider),
    ref.read(dataChangeProvider.notifier),
  ),
);
final googleDriveServiceProvider = Provider<GoogleDriveService>(
  (ref) => GoogleDriveService(),
);

final customerRepositoryProvider = Provider<PartyRepository>(
  (ref) => PartyRepository(
    ref.watch(appDatabaseProvider),
    ref.read(dataChangeProvider.notifier),
    PartyType.customer,
  ),
);
final supplierRepositoryProvider = Provider<PartyRepository>(
  (ref) => PartyRepository(
    ref.watch(appDatabaseProvider),
    ref.read(dataChangeProvider.notifier),
    PartyType.supplier,
  ),
);
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(
    ref.watch(appDatabaseProvider),
    ref.read(dataChangeProvider.notifier),
  ),
);
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    ref.watch(appDatabaseProvider),
    ref.read(dataChangeProvider.notifier),
  ),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(appDatabaseProvider),
    ref.read(dataChangeProvider.notifier),
  ),
);
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(appDatabaseProvider)),
);

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  ref.watch(dataChangeProvider);
  return ref.watch(reportRepositoryProvider).dashboard();
});

final customerBalancesProvider = FutureProvider<List<PartyBalance>>((
  ref,
) async {
  ref.watch(dataChangeProvider);
  return ref.watch(customerRepositoryProvider).balances();
});

final supplierBalancesProvider = FutureProvider<List<PartyBalance>>((
  ref,
) async {
  ref.watch(dataChangeProvider);
  return ref.watch(supplierRepositoryProvider).balances();
});

final categoriesProvider = FutureProvider<List<ExpenseCategory>>((ref) async {
  ref.watch(dataChangeProvider);
  return ref.watch(expenseRepositoryProvider).categories();
});

final recentTransactionsProvider = FutureProvider<List<FinancialTransaction>>((
  ref,
) async {
  ref.watch(dataChangeProvider);
  return ref.watch(transactionRepositoryProvider).list(limit: 6);
});

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    Future<void>.microtask(() async {
      final stored = await ref.read(settingsRepositoryProvider).get('locale');
      if (stored == 'en' || stored == 'ar') state = Locale(stored!);
    });
    return const Locale('ar');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref
        .read(settingsRepositoryProvider)
        .set('locale', locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
