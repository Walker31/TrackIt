import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/backup_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/sync_service.dart';

/// Backups protect device-only users and moving phones: a restore must
/// bring every row back intact, keep this install's own settings, and
/// leave the data untouched if the file is bad.
void main() {
  late Database db;
  final service = BackupService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<void> setting(String key, String value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> readSetting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// One synced transaction and an event with two members, an expense
  /// split between them and a settlement.
  Future<void> seed() async {
    final expense = Expense(
      amount: 250,
      category: ExpenseCategory.food,
      timestamp: DateTime(2026, 10, 20, 9),
      description: 'Lunch',
    ).toMap();
    await db.insert('expenses', {
      ...expense,
      'remote_id': 41,
      'is_synced': 1,
    });
    final group = await db.insert('groups', {
      'name': 'Goa trip',
      'remote_id': 7,
      'is_synced': 1,
    });
    final me = await db.insert('group_members', {
      'group_id': group,
      'username': 'Me',
      'is_synced': 1,
    });
    final asha = await db.insert('group_members', {
      'group_id': group,
      'username': 'Asha',
      'is_synced': 1,
    });
    final gexp = await db.insert('group_expenses', {
      'group_id': group,
      'payer_member_id': me,
      'amount': 1200.0,
      'category': 'food',
      'timestamp': '2026-10-27T12:00:00.000',
      'remote_id': 9,
      'is_synced': 1,
    });
    for (final member in [me, asha]) {
      await db.insert('group_expense_splits', {
        'expense_id': gexp,
        'member_id': member,
        'share_amount': 600.0,
      });
    }
    await db.insert('settlements', {
      'group_id': group,
      'from_member_id': asha,
      'to_member_id': me,
      'amount': 600.0,
      'timestamp': '2026-10-28T12:00:00.000',
      'is_synced': 1,
    });
    await setting('monthly_budget', '42000');
    await setting('theme_mode', 'dark');
  }

  Future<int> count(String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS c FROM $table')).first['c']
          as int;

  test('restores every row on a fresh install', () async {
    await seed();
    final json = await service.exportJson();

    // A new phone: empty database, already set up in server mode.
    db = await DatabaseService.openInMemoryForTesting();
    await setting('app_mode', 'server');
    await setting('server_url', 'https://example.test/api/');

    final summary = await service.restore(json);

    expect(summary.transactions, 1);
    expect(await count('expenses'), 1);
    expect(await count('groups'), 1);
    expect(await count('group_members'), 2);
    expect(await count('group_expense_splits'), 2);
    expect(await count('settlements'), 1);
    final row = (await db.query('expenses')).single;
    expect(row['description'], 'Lunch');
    expect(row['amount'], 250);
    expect(await readSetting('monthly_budget'), '42000');
    expect(await readSetting('theme_mode'), 'dark');
    // This install's own mode and server are kept.
    expect(await readSetting('app_mode'), 'server');
    expect(await readSetting('server_url'), 'https://example.test/api/');
  });

  test('same account keeps server ids; nothing to upload again', () async {
    await seed();
    final json = await service.exportJson(account: 'aditya');
    db = await DatabaseService.openInMemoryForTesting();

    await service.restore(json, account: 'aditya');

    final row = (await db.query('expenses')).single;
    expect(row['remote_id'], 41);
    expect(row['is_synced'], 1);
    expect(await SyncService.pendingChanges(), 0);
  });

  test('another account gets the rows as new, unsynced data', () async {
    await seed();
    final json = await service.exportJson(account: 'someone-else');
    db = await DatabaseService.openInMemoryForTesting();

    await service.restore(json, account: 'aditya');

    final row = (await db.query('expenses')).single;
    expect(row['remote_id'], isNull);
    expect(row['is_synced'], 0);
    final group = (await db.query('groups')).single;
    expect(group['remote_id'], isNull);
    // Expense, group, two members, group expense and settlement.
    expect(await SyncService.pendingChanges(), 6);
  });

  test('backups leave out sync cursors and device settings', () async {
    await seed();
    await setting('app_mode', 'server');
    await setting('last_sync_transactions', '2026-10-27T00:00:00Z');
    await setting('sync_last_success', '2026-10-27T00:00:00Z');

    final data = jsonDecode(await service.exportJson()) as Map;
    final keys = [
      for (final r in (data['tables'] as Map)['settings'] as List) r['key'],
    ];

    expect(keys, contains('monthly_budget'));
    expect(keys, isNot(contains('app_mode')));
    expect(keys, isNot(contains('last_sync_transactions')));
    expect(keys, isNot(contains('sync_last_success')));
  });

  test('rejects files that are not TrackIt backups', () {
    expect(() => service.inspect('not json'), throwsA(isA<BackupException>()));
    expect(
      () => service.inspect(jsonEncode({'app': 'other', 'tables': {}})),
      throwsA(isA<BackupException>()),
    );
  });

  test('rejects backups from a newer app version', () {
    final json = jsonEncode({
      'app': 'trackit',
      'format': 1,
      'schema': DatabaseService.schemaVersion + 1,
      'tables': {},
    });
    expect(() => service.inspect(json), throwsA(isA<BackupException>()));
  });

  test('a damaged backup changes nothing', () async {
    await seed();
    final data = jsonDecode(await service.exportJson()) as Map;
    // An expense without its required amount fails partway through.
    ((data['tables'] as Map)['expenses'] as List).add({'id': 99});

    await expectLater(
      service.restore(jsonEncode(data)),
      throwsA(isA<DatabaseException>()),
    );

    expect(await count('expenses'), 1);
    expect(await count('groups'), 1);
    expect(await readSetting('monthly_budget'), '42000');
  });
}
