import 'package:sqflite/sqflite.dart' as sql;

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models.dart';
import '../../../core/services/data_change_notifier.dart';

class ExpenseFilter {
  const ExpenseFilter({
    this.range = const DateRange(),
    this.categoryId,
    this.paymentMethod,
    this.query = '',
  });
  final DateRange range;
  final int? categoryId;
  final PaymentMethod? paymentMethod;
  final String query;
}

class ExpenseRepository {
  ExpenseRepository(this._database, this._changes);
  final AppDatabase _database;
  final DataChangeNotifier _changes;

  Future<List<ExpenseCategory>> categories() async {
    final db = await _database.instance;
    final rows = await db.query(
      'expense_categories',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(ExpenseCategory.fromMap).toList(growable: false);
  }

  Future<int> saveCategory(ExpenseCategory category) async {
    if (category.name.trim().isEmpty) {
      throw const ValidationException('categoryNameRequired');
    }
    final db = await _database.instance;
    try {
      final id = category.id == null
          ? await db.insert('expense_categories', category.toMap())
          : category.id!;
      if (category.id != null) {
        await db.update(
          'expense_categories',
          category.toMap(),
          where: 'id = ?',
          whereArgs: [category.id],
        );
      }
      _changes.notifyDataChanged();
      return id;
    } on sql.DatabaseException catch (error) {
      throw DatabaseException('categorySaveFailed', cause: error);
    }
  }

  Future<List<GeneralExpense>> list({
    ExpenseFilter filter = const ExpenseFilter(),
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _database.instance;
    final clauses = <String>[];
    final args = <Object?>[];
    if (filter.range.start != null) {
      clauses.add('expense_date >= ?');
      args.add(isoDate(filter.range.start!));
    }
    if (filter.range.end != null) {
      clauses.add('expense_date <= ?');
      args.add(isoDate(filter.range.end!));
    }
    if (filter.categoryId != null) {
      clauses.add('category_id = ?');
      args.add(filter.categoryId);
    }
    if (filter.paymentMethod != null) {
      clauses.add('payment_method = ?');
      args.add(filter.paymentMethod!.value);
    }
    if (filter.query.trim().isNotEmpty) {
      clauses.add('(description LIKE ? OR notes LIKE ?)');
      final value = '%${filter.query.trim()}%';
      args.addAll([value, value]);
    }
    final rows = await db.query(
      'general_expenses',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'expense_date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(GeneralExpense.fromMap).toList(growable: false);
  }

  Future<GeneralExpense?> find(int id) async {
    final db = await _database.instance;
    final rows = await db.query(
      'general_expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GeneralExpense.fromMap(rows.single);
  }

  Future<int> save(GeneralExpense expense) async {
    if (expense.amount <= 0 || !expense.amount.isFinite) {
      throw const ValidationException('amountInvalid');
    }
    if (expense.description.trim().isEmpty) {
      throw const ValidationException('descriptionRequired');
    }
    final db = await _database.instance;
    try {
      final categoryExists =
          sql.Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM expense_categories WHERE id = ?',
              [expense.categoryId],
            ),
          ) ??
          0;
      if (categoryExists != 1) {
        throw const ValidationException('categoryMissing');
      }
      late final int id;
      if (expense.id == null) {
        id = await db.insert('general_expenses', expense.toMap());
      } else {
        await db.update(
          'general_expenses',
          expense.copyWith(updatedAt: DateTime.now()).toMap(),
          where: 'id = ?',
          whereArgs: [expense.id],
        );
        id = expense.id!;
      }
      _changes.notifyDataChanged();
      return id;
    } on sql.DatabaseException catch (error) {
      throw DatabaseException('expenseSaveFailed', cause: error);
    }
  }

  Future<void> delete(int id) async {
    final db = await _database.instance;
    await db.delete('general_expenses', where: 'id = ?', whereArgs: [id]);
    _changes.notifyDataChanged();
  }

  Future<String> categoryName(int categoryId) async {
    final db = await _database.instance;
    final rows = await db.query(
      'expense_categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return rows.isEmpty ? '' : rows.single['name']! as String;
  }
}
