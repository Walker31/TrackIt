import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/expense_service.dart';
import 'package:trackit/services/sync_service.dart';

/// Pulling transactions into the local database, against the app's real
/// schema on an in-memory SQLite.
void main() {
  late Database db;
  final sync = SyncService();
  final today = DateTime.now();
  final todayDate =
      '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  /// A transaction as the backend serializes it.
  Map<String, dynamic> remote(
    int id,
    String amount, {
    String? clientId,
    String? note,
    bool deleted = false,
  }) => {
    'id': id,
    'client_id': clientId ?? 'remote-$id',
    'amount': amount,
    'type': 'expense',
    'txn_date': todayDate,
    'category': '00000000-0000-0000-0000-000000000001',
    'subcategory': null,
    'event': null,
    'payment_method': 'upi',
    'note': note,
    'attachment_url': null,
    'created_at': today.toUtc().toIso8601String(),
    'is_deleted': deleted,
  };

  Future<List<Map<String, Object?>>> rows() =>
      db.query('expenses', orderBy: 'id');

  Future<int> addLocal(double amount, {String? uuid}) async {
    final map = Expense(
      amount: amount,
      category: ExpenseCategory.food,
      timestamp: today,
      description: 'local $amount',
    ).toMap();
    map['is_synced'] = 0;
    if (uuid != null) map['uuid'] = uuid;
    return db.insert('expenses', map);
  }

  test('fresh device: inserts every pulled row', () async {
    await sync.mergeRemoteExpenses(db, [
      remote(1, '250.00'),
      remote(2, '99.00'),
      remote(3, '120.00'),
    ]);
    final all = await rows();
    expect(all.map((r) => r['remote_id']), [1, 2, 3]);
    expect(all.map((r) => r['amount']), [250.0, 99.0, 120.0]);
  });

  test(
    'server ids never overwrite unrelated local rows with the same id',
    () async {
      // Local-only rows that happen to occupy primary keys 1 and 2.
      await addLocal(10);
      await addLocal(20);

      await sync.mergeRemoteExpenses(db, [
        remote(1, '250.00'),
        remote(2, '99.00'),
      ]);

      final all = await rows();
      expect(all, hasLength(4));
      expect(all.where((r) => r['remote_id'] == null).map((r) => r['amount']), [
        10.0,
        20.0,
      ]);
    },
  );

  test('pulled rows show up in today\'s range queries', () async {
    await sync.mergeRemoteExpenses(db, [
      remote(1, '250.00'),
      remote(2, '99.00'),
    ]);
    final todays = await ExpenseService().getExpensesByDate(today);
    expect(todays.map((e) => e.amount), unorderedEquals([250.0, 99.0]));
  });

  test('pulling the same rows twice does not duplicate them', () async {
    final pulled = [remote(1, '250.00'), remote(2, '99.00')];
    await sync.mergeRemoteExpenses(db, pulled);
    await sync.mergeRemoteExpenses(db, pulled);
    expect(await rows(), hasLength(2));
  });

  test(
    'a row we pushed ourselves is linked by client_id, not duplicated',
    () async {
      final localId = await addLocal(45, uuid: 'abc-123');
      await sync.mergeRemoteExpenses(db, [
        remote(7, '45.00', clientId: 'abc-123'),
      ]);

      final all = await rows();
      expect(all, hasLength(1));
      expect(all.single['id'], localId);
      expect(all.single['remote_id'], 7);
    },
  );

  test(
    'server edits apply to synced rows but not to unpushed local edits',
    () async {
      await sync.mergeRemoteExpenses(db, [
        remote(1, '250.00'),
        remote(2, '99.00'),
      ]);
      // Row 2 has a local edit that hasn't been pushed yet.
      await db.update(
        'expenses',
        {'amount': 111.0, 'is_synced': 0},
        where: 'remote_id = ?',
        whereArgs: [2],
      );

      await sync.mergeRemoteExpenses(db, [
        remote(1, '300.00', note: 'edited elsewhere'),
        remote(2, '500.00'),
      ]);

      final byRemote = {for (final r in await rows()) r['remote_id']: r};
      expect(byRemote[1]!['amount'], 300.0);
      expect(byRemote[1]!['description'], 'edited elsewhere');
      expect(byRemote[2]!['amount'], 111.0, reason: 'local edit kept');
    },
  );

  test('tombstones delete the local copy', () async {
    await sync.mergeRemoteExpenses(db, [
      remote(1, '250.00'),
      remote(2, '99.00'),
    ]);
    await sync.mergeRemoteExpenses(db, [remote(1, '250.00', deleted: true)]);
    expect((await rows()).map((r) => r['remote_id']), [2]);
  });
}
