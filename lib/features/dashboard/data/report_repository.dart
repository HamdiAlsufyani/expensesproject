import '../../../core/database/app_database.dart';
import '../../../core/models.dart';
import '../../../core/services/data_change_notifier.dart';
import '../../customers/data/party_repository.dart';
import '../../transactions/data/transaction_repository.dart';

class ReportRepository {
  ReportRepository(this._database);
  final AppDatabase _database;

  Future<DashboardSummary> dashboard() async {
    final db = await _database.instance;
    final financial = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS transaction_expenses,
        COALESCE(SUM(CASE WHEN party_type = 'customer' AND type = 'debit' THEN amount ELSE 0 END), 0) AS customer_debit,
        COALESCE(SUM(CASE WHEN party_type = 'customer' AND type = 'credit' THEN amount ELSE 0 END), 0) AS customer_credit,
        COALESCE(SUM(CASE WHEN party_type = 'supplier' AND type = 'debit' THEN amount ELSE 0 END), 0) AS supplier_debit,
        COALESCE(SUM(CASE WHEN party_type = 'supplier' AND type = 'credit' THEN amount ELSE 0 END), 0) AS supplier_credit
      FROM transactions
    ''');
    final general = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS expenses FROM general_expenses',
    );
    final counts = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM customers) AS customers,
        (SELECT COUNT(*) FROM suppliers) AS suppliers
    ''');
    final categoryRows = await db.rawQuery('''
      SELECT c.name, COALESCE(SUM(e.amount), 0) AS total
      FROM expense_categories c LEFT JOIN general_expenses e ON e.category_id = c.id
      GROUP BY c.id HAVING total > 0 ORDER BY total DESC
    ''');
    final monthlyIncomeRows = await db.rawQuery("""
      SELECT substr(transaction_date, 1, 7) AS period, SUM(amount) AS total
      FROM transactions WHERE type = 'income' GROUP BY period ORDER BY period DESC LIMIT 6
    """);
    final monthlyExpenseRows = await db.rawQuery("""
      SELECT period, SUM(total) AS total FROM (
        SELECT substr(transaction_date, 1, 7) AS period, amount AS total FROM transactions WHERE type = 'expense'
        UNION ALL
        SELECT substr(expense_date, 1, 7) AS period, amount AS total FROM general_expenses
      ) GROUP BY period ORDER BY period DESC LIMIT 6
    """);
    final row = financial.single;
    final countRow = counts.single;
    final transactionExpenses = (row['transaction_expenses'] as num).toDouble();
    final generalExpenses = (general.single['expenses'] as num).toDouble();
    return DashboardSummary(
      income: (row['income'] as num).toDouble(),
      expenses: transactionExpenses + generalExpenses,
      customerDebit: (row['customer_debit'] as num).toDouble(),
      customerCredit: (row['customer_credit'] as num).toDouble(),
      supplierDebit: (row['supplier_debit'] as num).toDouble(),
      supplierCredit: (row['supplier_credit'] as num).toDouble(),
      customerCount: (countRow['customers'] as num).toInt(),
      supplierCount: (countRow['suppliers'] as num).toInt(),
      expenseCategories: {
        for (final item in categoryRows)
          item['name']! as String: (item['total'] as num).toDouble(),
      },
      monthlyIncome: {
        for (final item in monthlyIncomeRows)
          item['period']! as String: (item['total'] as num).toDouble(),
      },
      monthlyExpense: {
        for (final item in monthlyExpenseRows)
          item['period']! as String: (item['total'] as num).toDouble(),
      },
    );
  }

  Future<DashboardSummary> financialSummary({
    DateRange range = const DateRange(),
  }) async {
    final db = await _database.instance;
    final transactionConditions = <String>[];
    final transactionArgs = <Object?>[];
    if (range.start != null) {
      transactionConditions.add('transaction_date >= ?');
      transactionArgs.add(isoDate(range.start!));
    }
    if (range.end != null) {
      transactionConditions.add('transaction_date <= ?');
      transactionArgs.add(isoDate(range.end!));
    }
    final expenseConditions = <String>[];
    final expenseArgs = <Object?>[];
    if (range.start != null) {
      expenseConditions.add('expense_date >= ?');
      expenseArgs.add(isoDate(range.start!));
    }
    if (range.end != null) {
      expenseConditions.add('expense_date <= ?');
      expenseArgs.add(isoDate(range.end!));
    }
    final financial = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS transaction_expenses,
        COALESCE(SUM(CASE WHEN party_type = 'customer' AND type = 'debit' THEN amount ELSE 0 END), 0) AS customer_debit,
        COALESCE(SUM(CASE WHEN party_type = 'customer' AND type = 'credit' THEN amount ELSE 0 END), 0) AS customer_credit,
        COALESCE(SUM(CASE WHEN party_type = 'supplier' AND type = 'debit' THEN amount ELSE 0 END), 0) AS supplier_debit,
        COALESCE(SUM(CASE WHEN party_type = 'supplier' AND type = 'credit' THEN amount ELSE 0 END), 0) AS supplier_credit
      FROM transactions ${transactionConditions.isEmpty ? '' : 'WHERE ${transactionConditions.join(' AND ')}'}
    ''', transactionArgs);
    final general = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS expenses FROM general_expenses ${expenseConditions.isEmpty ? '' : 'WHERE ${expenseConditions.join(' AND ')}'}',
      expenseArgs,
    );
    final counts = await db.rawQuery(
      'SELECT (SELECT COUNT(*) FROM customers) AS customers, (SELECT COUNT(*) FROM suppliers) AS suppliers',
    );
    final row = financial.single;
    final countRow = counts.single;
    return DashboardSummary(
      income: (row['income'] as num).toDouble(),
      expenses:
          (row['transaction_expenses'] as num).toDouble() +
          (general.single['expenses'] as num).toDouble(),
      customerDebit: (row['customer_debit'] as num).toDouble(),
      customerCredit: (row['customer_credit'] as num).toDouble(),
      supplierDebit: (row['supplier_debit'] as num).toDouble(),
      supplierCredit: (row['supplier_credit'] as num).toDouble(),
      customerCount: (countRow['customers'] as num).toInt(),
      supplierCount: (countRow['suppliers'] as num).toInt(),
      expenseCategories: const {},
      monthlyIncome: const {},
      monthlyExpense: const {},
    );
  }

  Future<List<PartyBalance>> partyReport(
    PartyType type, {
    String query = '',
    DateRange range = const DateRange(),
  }) => PartyRepository(
    _database,
    _NoopDataChangeNotifier(),
    type,
  ).balances(query: query, range: range);

  Future<List<ExpenseReportRow>> expenseReport({
    DateRange range = const DateRange(),
  }) async {
    final db = await _database.instance;
    final clauses = <String>[];
    final args = <Object?>[];
    if (range.start != null) {
      clauses.add('e.expense_date >= ?');
      args.add(isoDate(range.start!));
    }
    if (range.end != null) {
      clauses.add('e.expense_date <= ?');
      args.add(isoDate(range.end!));
    }
    final rows = await db.rawQuery('''
      SELECT c.name AS category, COUNT(e.id) AS count, COALESCE(SUM(e.amount), 0) AS total
      FROM expense_categories c LEFT JOIN general_expenses e ON e.category_id = c.id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      GROUP BY c.id ORDER BY total DESC, c.name
    ''', args);
    return rows
        .map(
          (row) => ExpenseReportRow(
            category: row['category']! as String,
            count: (row['count'] as num).toInt(),
            total: (row['total'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<TransactionReportRow>> transactionReport({
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    final repository = TransactionRepository(
      _database,
      _NoopDataChangeNotifier(),
    );
    final transactions = await repository.list(filter: filter, limit: 500);
    return Future.wait(
      transactions.map(
        (transaction) async => TransactionReportRow(
          transaction: transaction,
          partyName: await repository.partyDisplayName(transaction),
        ),
      ),
    );
  }
}

class _NoopDataChangeNotifier extends DataChangeNotifier {
  @override
  void notifyDataChanged() {}
}
