import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Queue of server writes that must survive being offline.
///
/// Local deletes of already-synced rows are recorded here so they can be
/// replayed against the backend later; otherwise the next pull would bring
/// the deleted row straight back. The queue is only drained in server mode.
class SyncOutbox {
  SyncOutbox._();

  static const table = 'sync_outbox';

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        payload TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  static Future<void> enqueue(
    DatabaseExecutor db, {
    required String method,
    required String path,
    Map<String, dynamic>? payload,
  }) async {
    await db.insert(table, {
      'method': method,
      'path': path,
      'payload': payload == null ? null : jsonEncode(payload),
    });
  }

  static Future<void> enqueueDelete(DatabaseExecutor db, String path) =>
      enqueue(db, method: 'DELETE', path: path);

  static Future<int> pendingCount() async {
    final db = await DatabaseService().getDatabase();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Replay queued requests oldest-first. A request is dropped once the
  /// server accepted it or no longer has the resource (404/410). Network
  /// failures stop the drain so ordering is preserved for the next attempt.
  static Future<void> drain(ApiService api) async {
    final db = await DatabaseService().getDatabase();
    final rows = await db.query(table, orderBy: 'id ASC');

    for (final row in rows) {
      final id = row['id'] as int;
      try {
        final payload = row['payload'] as String?;
        await api.send(
          row['method'] as String,
          row['path'] as String,
          data: payload == null ? null : jsonDecode(payload),
        );
        await db.delete(table, where: 'id = ?', whereArgs: [id]);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404 || status == 410) {
          await db.delete(table, where: 'id = ?', whereArgs: [id]);
        } else if (e.response == null) {
          return;
        } else {
          debugPrint('Outbox request $id failed: $e');
          await db.update(
            table,
            {'attempts': (row['attempts'] as int) + 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }
  }
}
