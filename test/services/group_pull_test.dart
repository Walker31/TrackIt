import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/sync_service.dart';

/// Pulling groups, group expenses and settlements. Server edits and
/// deletes used to be ignored once a row existed locally.
void main() {
  late Database db;
  final sync = SyncService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
    await sync.mergeRemoteGroups(db, [
      {
        'id': 10,
        'client_id': 'g-10',
        'name': 'Goa trip',
        'icon': '🏖',
        'memberships': [
          {'id': 100, 'user': 1, 'username': 'asha', 'role': 'owner'},
          {'id': 101, 'user': 2, 'username': 'ravi', 'role': 'member'},
        ],
      },
    ]);
  });

  Map<String, dynamic> expense(
    int id,
    String amount, {
    List<(int, String)>? splits,
    bool deleted = false,
  }) => {
    'id': id,
    'client_id': 'ge-$id',
    'group': 10,
    'payer': 100,
    'amount': amount,
    'category': 'food',
    'description': 'Dinner',
    'timestamp': '2026-10-20T20:00:00',
    'receipt_url': null,
    'split_type': 'equal',
    'splits': [
      for (final (member, share) in splits ?? [(100, '50'), (101, '50')])
        {'id': member * 10 + id, 'member': member, 'share_amount': share},
    ],
    'is_deleted': deleted,
  };

  Future<Map<String, Object?>> expenseRow(int remoteId) async =>
      (await db.query(
        'group_expenses',
        where: 'remote_id = ?',
        whereArgs: [remoteId],
      )).single;

  Future<List<double>> shares(int remoteId) async {
    final rows = await db.rawQuery(
      'SELECT s.share_amount FROM group_expense_splits s '
      'JOIN group_expenses e ON e.id = s.expense_id '
      'WHERE e.remote_id = ? ORDER BY s.member_id',
      [remoteId],
    );
    return rows.map((r) => r['share_amount'] as double).toList();
  }

  test('groups and their members are inserted', () async {
    final members = await db.query('group_members', orderBy: 'remote_id');
    expect(members.map((m) => m['username']), ['asha', 'ravi']);
  });

  test('server edits to a synced group expense apply, splits too', () async {
    await sync.mergeRemoteGroupExpenses(db, [expense(1, '100')]);
    await sync.mergeRemoteGroupExpenses(db, [
      expense(1, '120', splits: [(100, '20'), (101, '100')]),
    ]);

    expect((await expenseRow(1))['amount'], 120.0);
    expect(await shares(1), [20.0, 100.0]);
    expect(await db.query('group_expenses'), hasLength(1));
  });

  test('unpushed local edits to a group expense are kept', () async {
    await sync.mergeRemoteGroupExpenses(db, [expense(1, '100')]);
    await db.update('group_expenses', {
      'amount': 80.0,
      'is_synced': 0,
    }, where: 'remote_id = 1');

    await sync.mergeRemoteGroupExpenses(db, [expense(1, '120')]);

    expect((await expenseRow(1))['amount'], 80.0);
  });

  test('group expense tombstones delete the local copy', () async {
    await sync.mergeRemoteGroupExpenses(db, [
      expense(1, '100'),
      expense(2, '40'),
    ]);
    await sync.mergeRemoteGroupExpenses(db, [expense(1, '100', deleted: true)]);

    final left = await db.query('group_expenses');
    expect(left.map((r) => r['remote_id']), [2]);
    expect(await db.query('group_expense_splits'), hasLength(2));
  });

  test('settlements take server edits and tombstones', () async {
    Map<String, dynamic> settlement(String amount, {bool deleted = false}) => {
      'id': 5,
      'client_id': 's-5',
      'group': 10,
      'from_member': 101,
      'to_member': 100,
      'amount': amount,
      'timestamp': '2026-10-21T10:00:00',
      'is_deleted': deleted,
    };

    await sync.mergeRemoteSettlements(db, [settlement('50')]);
    await sync.mergeRemoteSettlements(db, [settlement('60')]);
    final rows = await db.query('settlements');
    expect(rows.single['amount'], 60.0);

    await sync.mergeRemoteSettlements(db, [settlement('60', deleted: true)]);
    expect(await db.query('settlements'), isEmpty);
  });

  test('a group tombstone removes the group and everything in it', () async {
    await sync.mergeRemoteGroupExpenses(db, [expense(1, '100')]);
    await sync.mergeRemoteGroups(db, [
      {'id': 10, 'name': 'Goa trip', 'is_deleted': true},
    ]);

    expect(await db.query('groups'), isEmpty);
    expect(await db.query('group_members'), isEmpty);
    expect(await db.query('group_expenses'), isEmpty);
  });
}
