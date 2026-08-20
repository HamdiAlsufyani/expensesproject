import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../errors/app_exception.dart';
import '../models.dart';
import 'data_change_notifier.dart';

class BackupArtifact {
  const BackupArtifact({
    required this.databaseFile,
    required this.manifestFile,
  });
  final File databaseFile;
  final File manifestFile;
}

class BackupService {
  BackupService(this._database, this._changes);
  static const int backupFormatVersion = 1;
  static const _requiredTables = {
    'customers',
    'suppliers',
    'transactions',
    'expense_categories',
    'general_expenses',
    'app_settings',
  };
  final AppDatabase _database;
  final DataChangeNotifier _changes;

  Future<Directory> get _backupDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    final output = Directory(p.join(directory.path, 'backups'));
    await output.create(recursive: true);
    return output;
  }

  Future<BackupArtifact> createDatabaseBackup({bool safetyCopy = false}) async {
    try {
      final liveDb = await _database.instance;
      await liveDb.execute('PRAGMA wal_checkpoint(FULL)');
      final activePath = await _database.path;
      final directory = await _backupDirectory;
      final timestamp = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final prefix = safetyCopy ? 'auto_pre_restore' : 'backup';
      final target = File(p.join(directory.path, '${prefix}_$timestamp.db'));
      await File(activePath).copy(target.path);
      final digest = sha256.convert(await target.readAsBytes()).toString();
      final manifest = File('${target.path}.manifest.json');
      await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'backupFormatVersion': backupFormatVersion,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'schemaVersion': AppDatabase.schemaVersion,
          'databaseFilename': p.basename(target.path),
          'sha256': digest,
          'safetyCopy': safetyCopy,
        }),
      );
      return BackupArtifact(databaseFile: target, manifestFile: manifest);
    } catch (error) {
      throw BackupException('backupCreateFailed', cause: error);
    }
  }

  Future<File> exportJson() async {
    try {
      final db = await _database.instance;
      final directory = await _backupDirectory;
      final timestamp = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final file = File(p.join(directory.path, 'backup_$timestamp.json'));
      final payload = <String, Object?>{
        'backupFormatVersion': backupFormatVersion,
        'databaseVersion': AppDatabase.schemaVersion,
        'backupTimestamp': DateTime.now().toUtc().toIso8601String(),
        'customers': await db.query('customers', orderBy: 'id'),
        'suppliers': await db.query('suppliers', orderBy: 'id'),
        'transactions': await db.query('transactions', orderBy: 'id'),
        'expenseCategories': await db.query(
          'expense_categories',
          orderBy: 'id',
        ),
        'generalExpenses': await db.query('general_expenses', orderBy: 'id'),
        'settings': await db.query('app_settings', orderBy: 'id'),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      return file;
    } catch (error) {
      throw BackupException('jsonExportFailed', cause: error);
    }
  }

  Future<void> importJson(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const BackupException('invalidBackup');
      }
      _validateJsonPayload(decoded);
      final db = await _database.instance;
      await db.transaction((txn) async {
        await _insertJsonRows(
          txn,
          'customers',
          decoded['customers'] as List,
          <String>{
            'id',
            'name',
            'phone',
            'email',
            'address',
            'notes',
            'created_at',
            'updated_at',
          },
        );
        await _insertJsonRows(
          txn,
          'suppliers',
          decoded['suppliers'] as List,
          <String>{
            'id',
            'name',
            'phone',
            'email',
            'address',
            'notes',
            'created_at',
            'updated_at',
          },
        );
        await _insertJsonRows(
          txn,
          'expense_categories',
          decoded['expenseCategories'] as List,
          <String>{'id', 'name', 'description', 'created_at'},
        );
        await _insertJsonRows(
          txn,
          'transactions',
          decoded['transactions'] as List,
          <String>{
            'id',
            'type',
            'party_type',
            'party_id',
            'amount',
            'description',
            'transaction_date',
            'payment_method',
            'reference_number',
            'notes',
            'created_at',
            'updated_at',
          },
        );
        await _insertJsonRows(
          txn,
          'general_expenses',
          decoded['generalExpenses'] as List,
          <String>{
            'id',
            'category_id',
            'amount',
            'description',
            'expense_date',
            'payment_method',
            'notes',
            'created_at',
            'updated_at',
          },
        );
        await _insertJsonRows(
          txn,
          'app_settings',
          decoded['settings'] as List,
          <String>{'id', 'key', 'value'},
        );
      });
      _changes.notifyDataChanged();
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException('invalidBackup', cause: error);
    }
  }

  Future<void> restoreDatabase(File candidate) async {
    try {
      await validateDatabase(candidate);
      await createDatabaseBackup(safetyCopy: true);
      final livePath = await _database.path;
      final incoming = File('$livePath.incoming');
      await candidate.copy(incoming.path);
      await validateDatabase(incoming);
      await _database.close();
      final live = File(livePath);
      final old = File('$livePath.pre_restore');
      if (await old.exists()) await old.delete();
      if (await live.exists()) await live.rename(old.path);
      try {
        await incoming.rename(livePath);
        await _database.reopen();
        await old.delete();
        _changes.notifyDataChanged();
      } catch (error) {
        if (await live.exists()) await live.delete();
        if (await old.exists()) await old.rename(livePath);
        await _database.reopen();
        throw BackupException('restoreFailed', cause: error);
      }
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException('restoreFailed', cause: error);
    }
  }

  Future<void> validateDatabase(File file) async {
    if (!await file.exists() || await file.length() < 4096) {
      throw const BackupException('invalidBackup');
    }
    Database? candidate;
    try {
      candidate = await openDatabase(
        file.path,
        readOnly: true,
        singleInstance: false,
      );
      final integrity = await candidate.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.single.values.first != 'ok') {
        throw const BackupException('invalidBackup');
      }
      final tables = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final present = tables.map((row) => row['name'] as String).toSet();
      if (!_requiredTables.every(present.contains)) {
        throw const BackupException('invalidBackup');
      }
      final schema =
          Sqflite.firstIntValue(
            await candidate.rawQuery('PRAGMA user_version'),
          ) ??
          0;
      if (schema > AppDatabase.schemaVersion) {
        throw const BackupException('invalidBackup');
      }
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException('invalidBackup', cause: error);
    } finally {
      await candidate?.close();
    }
  }

  void _validateJsonPayload(Map<String, dynamic> payload) {
    final required = [
      'customers',
      'suppliers',
      'transactions',
      'expenseCategories',
      'generalExpenses',
      'settings',
    ];
    if (payload['databaseVersion'] is! num ||
        payload['backupTimestamp'] is! String ||
        !required.every((key) => payload[key] is List)) {
      throw const BackupException('invalidBackup');
    }
    if ((payload['databaseVersion'] as num).toInt() > AppDatabase.schemaVersion) {
      throw const BackupException('invalidBackup');
    }
    for (final row in payload['customers'] as List) {
      _validatePartyRow(row);
    }
    for (final row in payload['suppliers'] as List) {
      _validatePartyRow(row);
    }
    for (final row in payload['expenseCategories'] as List) {
      if (row is! Map ||
          row['id'] is! num ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty) {
        throw const BackupException('invalidBackup');
      }
    }
    for (final row in payload['transactions'] as List) {
      _validateTransactionRow(row);
    }
    for (final row in payload['generalExpenses'] as List) {
      _validateExpenseRow(row);
    }
    for (final row in payload['settings'] as List) {
      if (row is! Map || row['key'] is! String || row['value'] is! String) {
        throw const BackupException('invalidBackup');
      }
    }
  }

  void _validatePartyRow(Object? row) {
    if (row is! Map ||
        row['id'] is! num ||
        row['name'] is! String ||
        (row['name'] as String).trim().isEmpty) {
      throw const BackupException('invalidBackup');
    }
  }

  void _validateTransactionRow(Object? row) {
    if (row is! Map ||
        row['id'] is! num ||
        row['amount'] is! num ||
        (row['amount'] as num).toDouble() <= 0 ||
        row['description'] is! String ||
        row['transaction_date'] is! String ||
        row['type'] is! String ||
        row['party_type'] is! String ||
        row['payment_method'] is! String) {
      throw const BackupException('invalidBackup');
    }
    try {
      TransactionTypeValue.fromDb(row['type'] as String);
      final partyType = PartyTypeValue.fromDb(row['party_type'] as String);
      PaymentMethodValue.fromDb(row['payment_method'] as String);
      DateTime.parse(row['transaction_date'] as String);
      if ((partyType == PartyType.general) != (row['party_id'] == null)) {
        throw const BackupException('invalidBackup');
      }
    } catch (_) {
      throw const BackupException('invalidBackup');
    }
  }

  void _validateExpenseRow(Object? row) {
    if (row is! Map ||
        row['id'] is! num ||
        row['category_id'] is! num ||
        row['amount'] is! num ||
        (row['amount'] as num).toDouble() <= 0 ||
        row['description'] is! String ||
        row['expense_date'] is! String ||
        row['payment_method'] is! String) {
      throw const BackupException('invalidBackup');
    }
    try {
      DateTime.parse(row['expense_date'] as String);
      PaymentMethodValue.fromDb(row['payment_method'] as String);
    } catch (_) {
      throw const BackupException('invalidBackup');
    }
  }

  Future<void> _insertJsonRows(
    Transaction txn,
    String table,
    List rows,
    Set<String> allowed,
  ) async {
    for (final source in rows) {
      if (source is! Map) throw const BackupException('invalidBackup');
      final row = <String, Object?>{};
      for (final entry in source.entries) {
        if (entry.key is String && allowed.contains(entry.key)) {
          row[entry.key as String] = entry.value;
        }
      }
      await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
