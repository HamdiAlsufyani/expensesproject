import 'package:sqflite/sqflite.dart' as sql;

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models.dart';
import '../../../core/services/data_change_notifier.dart';

class PartyRepository {
  PartyRepository(this._database, this._changes, this.type)
    : assert(type != PartyType.general);

  final AppDatabase _database;
  final DataChangeNotifier _changes;
  final PartyType type;

  String get _table => type == PartyType.customer ? 'customers' : 'suppliers';

  Future<List<Party>> list({
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _database.instance;
    final normalized = query.trim();
    final where = normalized.isEmpty
        ? null
        : '(name LIKE ? OR phone LIKE ? OR email LIKE ?)';
    final args = normalized.isEmpty
        ? null
        : List<Object?>.filled(3, '%$normalized%');
    final rows = await db.query(
      _table,
      where: where,
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Party.fromMap).toList(growable: false);
  }

  Future<Party?> find(int id) async {
    final db = await _database.instance;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Party.fromMap(rows.single);
  }

  Future<int> save(Party party) async {
    if (party.name.trim().isEmpty) {
      throw const ValidationException('partyNameRequired');
    }
    if (party.email != null &&
        party.email!.trim().isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(party.email!.trim())) {
      throw const ValidationException('invalidEmail');
    }
    final db = await _database.instance;
    try {
      late final int id;
      if (party.id == null) {
        id = await db.insert(_table, party.toMap());
      } else {
        await db.update(
          _table,
          party.copyWith(updatedAt: DateTime.now()).toMap(),
          where: 'id = ?',
          whereArgs: [party.id],
        );
        id = party.id!;
      }
      _changes.notifyDataChanged();
      return id;
    } on sql.DatabaseException catch (error) {
      throw DatabaseException('partySaveFailed', cause: error);
    }
  }

  Future<void> delete(int id) async {
    final db = await _database.instance;
    final linked =
        sql.Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM transactions WHERE party_type = ? AND party_id = ?',
            [type.value, id],
          ),
        ) ??
        0;
    if (linked > 0) throw const ValidationException('partyHasTransactions');
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    _changes.notifyDataChanged();
  }

  Future<PartyBalance> balanceFor(Party party) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0) AS debit,
        COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0) AS credit
      FROM transactions WHERE party_type = ? AND party_id = ?
    ''',
      [type.value, party.id],
    );
    final row = rows.single;
    return PartyBalance(
      party: party,
      debit: (row['debit'] as num).toDouble(),
      credit: (row['credit'] as num).toDouble(),
    );
  }

  Future<List<PartyBalance>> balances({
    String query = '',
    DateRange range = const DateRange(),
  }) async {
    final db = await _database.instance;
    final normalized = query.trim();
    final where = normalized.isEmpty
        ? ''
        : 'WHERE p.name LIKE ? OR p.phone LIKE ?';
    final joinDates = <String>[];
    final args = <Object?>[type.value];
    if (range.start != null) {
      joinDates.add('t.transaction_date >= ?');
      args.add(isoDate(range.start!));
    }
    if (range.end != null) {
      joinDates.add('t.transaction_date <= ?');
      args.add(isoDate(range.end!));
    }
    if (normalized.isNotEmpty) args.addAll(['%$normalized%', '%$normalized%']);
    final rows = await db.rawQuery('''
      SELECT p.*, 
        COALESCE(SUM(CASE WHEN t.type = 'debit' THEN t.amount ELSE 0 END), 0) AS debit,
        COALESCE(SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE 0 END), 0) AS credit
      FROM $_table p
      LEFT JOIN transactions t ON t.party_type = ? AND t.party_id = p.id${joinDates.isEmpty ? '' : ' AND ${joinDates.join(' AND ')}'}
      $where
      GROUP BY p.id
      ORDER BY p.name COLLATE NOCASE ASC
    ''', args);
    return rows
        .map(
          (row) => PartyBalance(
            party: Party.fromMap(row),
            debit: (row['debit'] as num).toDouble(),
            credit: (row['credit'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }
}
