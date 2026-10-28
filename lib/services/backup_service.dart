import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';
import 'sync_outbox.dart';

/// Thrown when a file can't be restored; [message] is shown to the user.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// What a backup holds, for confirmation and success messages.
class BackupSummary {
  final int transactions;
  final int workouts;
  final DateTime? createdAt;

  const BackupSummary({
    required this.transactions,
    required this.workouts,
    this.createdAt,
  });
}

/// Whole-database backup as a JSON file: every table's rows, plus enough
/// metadata to restore safely on this or another phone.
///
/// Restoring replaces everything on the device in one transaction, so a
/// bad file leaves the current data untouched.
class BackupService {
  BackupService({DatabaseService? database})
    : _db = database ?? DatabaseService();

  final DatabaseService _db;

  static const _app = 'trackit';
  static const _format = 1;

  /// Bookkeeping that belongs to this device, not to the user's data.
  static const _skipTables = {
    'sqlite_sequence',
    'android_metadata',
    SyncOutbox.table,
  };

  /// Settings that describe this install (mode, server, sync position).
  static bool _isDeviceSetting(Object? key) {
    final k = key?.toString() ?? '';
    return k == 'app_mode' ||
        k == 'server_url' ||
        k.startsWith('last_sync_') ||
        k.startsWith('sync_');
  }

  Future<List<String>> _tables(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    );
    return [
      for (final r in rows)
        if (!_skipTables.contains(r['name'])) r['name'] as String,
    ];
  }

  Future<Set<String>> _columns(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    return {for (final r in rows) r['name'] as String};
  }

  /// The backup file's contents. [account] is the signed-in username, or
  /// null on a device-only install.
  Future<String> exportJson({String? account}) async {
    final db = await _db.getDatabase();
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in await _tables(db)) {
      final rows = await db.query(table);
      tables[table] = table == 'settings'
          ? [
              for (final r in rows)
                if (!_isDeviceSetting(r['key'])) r,
            ]
          : rows;
    }
    return const JsonEncoder.withIndent(' ').convert({
      'app': _app,
      'format': _format,
      'schema': DatabaseService.schemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'account': account,
      'tables': tables,
    });
  }

  /// Read and check a backup without changing anything.
  BackupSummary inspect(String json) {
    final data = _parse(json);
    final tables = data['tables'] as Map;
    int count(String t) => (tables[t] as List?)?.length ?? 0;
    return BackupSummary(
      transactions: count('expenses'),
      workouts: count('workouts'),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupException("This file isn't a TrackIt backup.");
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != _app ||
        decoded['tables'] is! Map) {
      throw const BackupException("This file isn't a TrackIt backup.");
    }
    if ((decoded['format'] as num? ?? 0) > _format ||
        (decoded['schema'] as num? ?? 0) > DatabaseService.schemaVersion) {
      throw const BackupException(
        'This backup was made by a newer version of TrackIt. '
        'Update the app, then restore it.',
      );
    }
    return decoded;
  }

  /// Replace everything on this device with the backup.
  ///
  /// A backup from the same account (or device-only to device-only) keeps
  /// its server ids, so nothing is uploaded twice. From a different
  /// account, rows lose their server ids and are marked unsynced: they
  /// upload as new data to the current account, or stay local offline.
  Future<BackupSummary> restore(String json, {String? account}) async {
    final data = _parse(json);
    final summary = inspect(json);
    final backup = (data['tables'] as Map).cast<String, dynamic>();
    final sameAccount = data['account'] == account;
    final db = await _db.getDatabase();

    await db.transaction((txn) async {
      // Rows go in parent-or-child order as they come; foreign keys are
      // checked once, at commit.
      await txn.execute('PRAGMA defer_foreign_keys = ON');

      final tables = await _tables(txn);

      // Empty everything first: clearing a parent table after its children
      // were refilled would cascade-delete the restored child rows.
      for (final table in tables) {
        if (table == 'settings') {
          // This install keeps its mode and server; sync cursors go, so the
          // next sync does a full pull against the restored data.
          await txn.delete(
            'settings',
            where: 'key NOT IN (?, ?)',
            whereArgs: ['app_mode', 'server_url'],
          );
        } else {
          await txn.delete(table);
        }
      }

      for (final table in tables) {
        final rows = backup[table];
        if (rows is! List) continue;
        final columns = await _columns(txn, table);
        final hasRemoteId = columns.contains('remote_id');
        final hasSynced = columns.contains('is_synced');

        for (final raw in rows) {
          if (raw is! Map) continue;
          if (table == 'settings' && _isDeviceSetting(raw['key'])) continue;
          // Columns this version doesn't have are dropped; missing ones
          // take their defaults.
          final row = <String, Object?>{
            for (final e in raw.entries)
              if (columns.contains(e.key)) e.key as String: e.value,
          };
          if (!sameAccount) {
            if (hasRemoteId) row['remote_id'] = null;
            if (hasSynced) row['is_synced'] = 0;
          }
          // Tables are empty, so a clash means a damaged file: let it fail
          // and roll the whole restore back.
          await txn.insert(table, row);
        }
      }
    });
    return summary;
  }
}
