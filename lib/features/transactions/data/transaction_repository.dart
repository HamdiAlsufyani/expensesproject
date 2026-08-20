import 'package:sqflite/sqflite.dart' as sql;

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models.dart';
import '../../../core/services/data_change_notifier.dart';

class TransactionFilter {
  const TransactionFilter({
    this.range = const DateRange(),
    this.partyType,
    this.partyId,
    this.type,
    this.paymentMethod,
    this.query = '',
  });
  final DateRange range;
  final PartyType? partyType;
  final int? partyId;
  final TransactionType? type;
  final PaymentMethod? paymentMethod;
  final String query;
}

class TransactionRepository {
  TransactionRepository(this._database, this._changes);
  final AppDatabase _database;
  final DataChangeNotifier _changes;

  Future<List<FinancialTransaction>> list({
    TransactionFilter filter = const TransactionFilter(),
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _database.instance;
    final clauses = <String>[];
    final args = <Object?>[];
    _appendFilter(filter, clauses, args);
    final rows = await db.query(
      'transactions',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'transaction_date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(FinancialTransaction.fromMap).toList(growable: false);
  }

  Future<FinancialTransaction?> find(int id) async {
    final db = await _database.instance;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : FinancialTransaction.fromMap(rows.single);
  }

  Future<int> save(FinancialTransaction transaction) async {
    _validate(transaction);
    final db = await _database.instance;
    try {
      await db.transaction((txn) async {
        await _validateParty(txn, transaction);
        if (transaction.id == null) {
          final id = await txn.insert('transactions', transaction.toMap());
          _lastSavedId = id;
        } else {
          await txn.update(
            'transactions',
            transaction.copyWith(updatedAt: DateTime.now()).toMap(),
            where: 'id = ?',
            whereArgs: [transaction.id],
          );
          _lastSavedId = transaction.id!;
        }
      });
      _changes.notifyDataChanged();
      return _lastSavedId!;
    } on sql.DatabaseException catch (error) {
      throw DatabaseException('transactionSaveFailed', cause: error);
    }
  }

  int? _lastSavedId;

  Future<void> delete(int id) async {
    final db = await _database.instance;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    _changes.notifyDataChanged();
  }

  Future<List<StatementLine>> statement(
    PartyType type,
    int partyId, {
    DateRange range = const DateRange(),
  }) async {
    if (type == PartyType.general) {
      throw const ValidationException('invalidStatementParty');
    }
    final db = await _database.instance;
    final clauses = <String>[
      'party_type = ?',
      'party_id = ?',
      "type IN ('debit','credit')",
    ];
    final args = <Object?>[type.value, partyId];
    if (range.start != null) {
      clauses.add('transaction_date >= ?');
      args.add(isoDate(range.start!));
    }
    if (range.end != null) {
      clauses.add('transaction_date <= ?');
      args.add(isoDate(range.end!));
    }
    final rows = await db.query(
      'transactions',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'transaction_date ASC, id ASC',
    );
    var balance = 0.0;
    return rows
        .map((row) {
          final record = FinancialTransaction.fromMap(row);
          final debit = record.type == TransactionType.debit
              ? record.amount
              : 0.0;
          final credit = record.type == TransactionType.credit
              ? record.amount
              : 0.0;
          balance += debit - credit;
          return StatementLine(
            transaction: record,
            debit: debit,
            credit: credit,
            balance: balance,
          );
        })
        .toList(growable: false);
  }

  Future<String> partyDisplayName(FinancialTransaction transaction) async {
    if (transaction.partyType == PartyType.general ||
        transaction.partyId == null) {
      return '';
    }
    final table = transaction.partyType == PartyType.customer
        ? 'customers'
        : 'suppliers';
    final db = await _database.instance;
    final rows = await db.query(
      table,
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [transaction.partyId],
      limit: 1,
    );
    return rows.isEmpty ? '' : rows.single['name']! as String;
  }

  void _validate(FinancialTransaction transaction) {
    if (transaction.amount <= 0 || !transaction.amount.isFinite) {
      throw const ValidationException('amountInvalid');
    }
    if (transaction.description.trim().isEmpty) {
      throw const ValidationException('descriptionRequired');
    }
    final partyIsGeneral = transaction.partyType == PartyType.general;
    if (partyIsGeneral && transaction.partyId != null) {
      throw const ValidationException('generalPartyIdInvalid');
    }
    if (!partyIsGeneral && transaction.partyId == null) {
      throw const ValidationException('partyRequired');
    }
    if (partyIsGeneral &&
        !(transaction.type == TransactionType.income ||
            transaction.type == TransactionType.expense)) {
      throw const ValidationException('generalTypeInvalid');
    }
    if (!partyIsGeneral &&
        !(transaction.type == TransactionType.debit ||
            transaction.type == TransactionType.credit)) {
      throw const ValidationException('partyTypeInvalid');
    }
  }

  Future<void> _validateParty(
    sql.Transaction txn,
    FinancialTransaction transaction,
  ) async {
    if (transaction.partyType == PartyType.general) return;
    final table = transaction.partyType == PartyType.customer
        ? 'customers'
        : 'suppliers';
    final count =
        sql.Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM $table WHERE id = ?', [
            transaction.partyId,
          ]),
        ) ??
        0;
    if (count != 1) throw const ValidationException('partyMissing');
  }

  void _appendFilter(
    TransactionFilter filter,
    List<String> clauses,
    List<Object?> args,
  ) {
    if (filter.range.start != null) {
      clauses.add('transaction_date >= ?');
      args.add(isoDate(filter.range.start!));
    }
    if (filter.range.end != null) {
      clauses.add('transaction_date <= ?');
      args.add(isoDate(filter.range.end!));
    }
    if (filter.partyType != null) {
      clauses.add('party_type = ?');
      args.add(filter.partyType!.value);
    }
    if (filter.partyId != null) {
      clauses.add('party_id = ?');
      args.add(filter.partyId);
    }
    if (filter.type != null) {
      clauses.add('type = ?');
      args.add(filter.type!.value);
    }
    if (filter.paymentMethod != null) {
      clauses.add('payment_method = ?');
      args.add(filter.paymentMethod!.value);
    }
    if (filter.query.trim().isNotEmpty) {
      clauses.add(
        '(description LIKE ? OR reference_number LIKE ? OR notes LIKE ?)',
      );
      final value = '%${filter.query.trim()}%';
      args.addAll([value, value, value]);
    }
  }
}
