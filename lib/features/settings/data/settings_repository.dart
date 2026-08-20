import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/data_change_notifier.dart';

class SettingsRepository {
  SettingsRepository(this._database, this._changes);
  final AppDatabase _database;
  final DataChangeNotifier _changes;

  Future<String?> get(String key) async {
    final db = await _database.instance;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> set(String key, String value) async {
    final db = await _database.instance;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changes.notifyDataChanged();
  }
}
