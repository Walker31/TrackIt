import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'database_service.dart';

/// Small user preferences kept in the `settings` table, so they travel with
/// backups like the rest of the data.
class PrefsService {
  final DatabaseService _db = DatabaseService();

  static const restSeconds = 'rest_seconds';
  static const weightStep = 'weight_step';
  static const reminderEnabled = 'reminder_enabled';
  static const reminderTime = 'reminder_time'; // "HH:mm"

  Future<String?> get(String key) async {
    final db = await _db.getDatabase();
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _db.getDatabase();
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getInt(String key, int fallback) async =>
      int.tryParse(await get(key) ?? '') ?? fallback;

  Future<double> getDouble(String key, double fallback) async =>
      double.tryParse(await get(key) ?? '') ?? fallback;

  Future<bool> getBool(String key, bool fallback) async {
    final v = await get(key);
    return v == null ? fallback : v == '1';
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');
}
