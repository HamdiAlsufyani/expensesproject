import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';

class AppDatabase {
  AppDatabase({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const int schemaVersion = 1;
  static const String fileName = 'expenses.sqlite';
  final Future<Directory> Function() _directoryProvider;
  Database? _database;
  String? _databasePath;

  Future<String> get path async {
    if (_databasePath != null) return _databasePath!;
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return _databasePath = p.join(directory.path, fileName);
  }

  Future<Database> get instance async => _database ??= await _open();

  Future<Database> _open() async {
    final dbPath = await path;
    return openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrate(db, oldVersion, newVersion);
      },
    );
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('debit','credit','expense','income')),
        party_type TEXT NOT NULL CHECK(party_type IN ('customer','supplier','general')),
        party_id INTEGER,
        amount REAL NOT NULL CHECK(amount > 0),
        description TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','bankTransfer','card','other')),
        reference_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK((party_type = 'general' AND party_id IS NULL) OR (party_type != 'general' AND party_id IS NOT NULL))
      )
    ''');
    await db.execute('''
      CREATE TABLE general_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL CHECK(amount > 0),
        description TEXT NOT NULL,
        expense_date TEXT NOT NULL,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','bankTransfer','card','other')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES expense_categories(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX idx_suppliers_phone ON suppliers(phone)');
    await db.execute(
      'CREATE INDEX idx_transactions_party_date ON transactions(party_type, party_id, transaction_date, id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_type ON transactions(type)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_reference ON transactions(reference_number)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_category_date ON general_expenses(category_id, expense_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_date ON general_expenses(expense_date DESC, id DESC)',
    );
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) await _createSchema(db);
  }

  Future<void> _seed(DatabaseExecutor db) async {
    final stamp = nowDb();
    for (final category in const [
      ['Rent', 'Monthly premises costs'],
      ['Electricity', 'Utility costs'],
      ['Internet', 'Connectivity costs'],
      ['Salaries', 'Team payroll'],
      ['Transportation', 'Travel and delivery'],
      ['Maintenance', 'Repairs and servicing'],
      ['Other', 'Other operating expenses'],
    ]) {
      await db.insert('expense_categories', {
        'name': category[0],
        'description': category[1],
        'created_at': stamp,
      });
    }
    await db.insert('app_settings', {'key': 'locale', 'value': 'ar'});
    await db.insert('app_settings', {'key': 'currency', 'value': 'SAR'});
    final customerId = await db.insert('customers', {
      'name': 'مؤسسة النور التجارية',
      'phone': '0500000001',
      'email': 'sales@example.com',
      'address': 'Riyadh',
      'notes': 'Demo customer',
      'created_at': stamp,
      'updated_at': stamp,
    });
    final supplierId = await db.insert('suppliers', {
      'name': 'شركة الإمداد الحديثة',
      'phone': '0500000002',
      'email': 'supply@example.com',
      'address': 'Riyadh',
      'notes': 'Demo supplier',
      'created_at': stamp,
      'updated_at': stamp,
    });
    final date = isoDate(DateTime.now());
    await db.insert('transactions', {
      'type': 'income',
      'party_type': 'general',
      'party_id': null,
      'amount': 12500.0,
      'description': 'Demo sales income',
      'transaction_date': date,
      'payment_method': 'bankTransfer',
      'reference_number': 'DEMO-001',
      'notes': null,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('transactions', {
      'type': 'debit',
      'party_type': 'customer',
      'party_id': customerId,
      'amount': 4800.0,
      'description': 'Invoice due from demo customer',
      'transaction_date': date,
      'payment_method': 'bankTransfer',
      'reference_number': 'INV-1001',
      'notes': null,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('transactions', {
      'type': 'credit',
      'party_type': 'supplier',
      'party_id': supplierId,
      'amount': 2300.0,
      'description': 'Payable to demo supplier',
      'transaction_date': date,
      'payment_method': 'bankTransfer',
      'reference_number': 'BILL-1001',
      'notes': null,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('general_expenses', {
      'category_id': 1,
      'amount': 5000.0,
      'description': 'Demo monthly rent',
      'expense_date': date,
      'payment_method': 'bankTransfer',
      'notes': null,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('general_expenses', {
      'category_id': 2,
      'amount': 800.0,
      'description': 'Demo electricity',
      'expense_date': date,
      'payment_method': 'cash',
      'notes': null,
      'created_at': stamp,
      'updated_at': stamp,
    });
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> reopen() async {
    await close();
    await instance;
  }
}
