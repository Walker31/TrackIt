import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/sync_outbox.dart';
import 'package:trackit/services/sync_service.dart';

/// A push used to mark its row synced whatever happened while the request
/// was in flight, so an edit made then never reached the server (and the
/// next pull overwrote it).
void main() {
  late Database db;
  final sync = SyncService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<Map<String, Object?>> addExpense() async {
    final id = await db.insert(
      'expenses',
      Expense(
        amount: 200,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 10, 30),
        description: 'Dinner',
      ).toMap(),
    );
    return (await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
  }

  Future<Map<String, Object?>> row(String table, Object? id) async =>
      (await db.query(table, where: 'id = ?', whereArgs: [id])).single;

  test('an unchanged row is marked synced with its server id', () async {
    final sent = await addExpense();

    await sync.markPushed(
      db,
      'expenses',
      sent,
      remoteId: 55,
      path: 'transactions/',
    );

    final now = await row('expenses', sent['id']);
    expect(now['remote_id'], 55);
    expect(now['is_synced'], 1);
  });

  test('an edit made during the push stays unsynced', () async {
    final sent = await addExpense();
    await db.update(
      'expenses',
      {'amount': 250.0},
      where: 'id = ?',
      whereArgs: [sent['id']],
    );

    await sync.markPushed(
      db,
      'expenses',
      sent,
      remoteId: 55,
      path: 'transactions/',
    );

    final now = await row('expenses', sent['id']);
    expect(now['remote_id'], 55, reason: 'the next push must be a PUT');
    expect(now['is_synced'], 0);
    expect(now['amount'], 250.0);
  });

  test('a change to nested rows also keeps it unsynced', () async {
    final sent = await addExpense();

    await sync.markPushed(
      db,
      'expenses',
      sent,
      remoteId: 55,
      path: 'transactions/',
      children: (_) async => 'after',
      sentChildren: 'before',
    );

    expect((await row('expenses', sent['id']))['is_synced'], 0);
  });

  test(
    'a row deleted during its first push is deleted on the server',
    () async {
      final sent = await addExpense();
      await db.delete('expenses', where: 'id = ?', whereArgs: [sent['id']]);

      await sync.markPushed(
        db,
        'expenses',
        sent,
        remoteId: 55,
        path: 'transactions/',
      );

      final queued = await db.query(SyncOutbox.table);
      expect(queued.single['method'], 'DELETE');
      expect(queued.single['path'], 'transactions/55/');
    },
  );
}
