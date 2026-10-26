import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/group_service.dart';
import 'package:trackit/services/sync_service.dart';

/// Editing and deleting groups, group expenses and payments locally.
void main() {
  late Database db;
  final service = GroupService();
  final sync = SyncService();
  late int groupId;
  late int asha;
  late int ravi;

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
    // A group that is already on the server.
    await sync.mergeRemoteGroups(db, [
      {
        'id': 10,
        'name': 'Goa trip',
        'icon': '🏖',
        'created_at': '2026-10-01T09:00:00Z',
        'memberships': [
          {'id': 100, 'user': 1, 'username': 'asha', 'role': 'owner'},
          {'id': 101, 'user': 2, 'username': 'ravi', 'role': 'member'},
        ],
      },
    ]);
    groupId = (await db.query('groups')).single['id'] as int;
    final members = await db.query('group_members', orderBy: 'remote_id');
    asha = members[0]['id'] as int;
    ravi = members[1]['id'] as int;
  });

  Future<GroupExpense> addSyncedExpense() async {
    final added = await service.addGroupExpense(
      GroupExpense(
        groupId: groupId,
        payerMemberId: asha,
        amount: 100,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 10, 20),
        splits: [
          ExpenseSplit(expenseId: 0, memberId: asha, shareAmount: 50),
          ExpenseSplit(expenseId: 0, memberId: ravi, shareAmount: 50),
        ],
      ),
    );
    await db.update(
      'group_expenses',
      {'remote_id': 7, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [added.id],
    );
    return added;
  }

  Future<List<String>> queuedPaths() async => [
    for (final r in await db.query('sync_outbox', orderBy: 'id'))
      r['path'] as String,
  ];

  test('renaming a group marks it for the next push', () async {
    await service.updateGroup(groupId, name: 'Goa 2026');
    final row = (await db.query('groups')).single;
    expect(row['name'], 'Goa 2026');
    expect(row['icon'], '🏖', reason: 'unchanged fields are kept');
    expect(row['is_synced'], 0);
    expect(row['remote_id'], 10);
  });

  test('editing an expense replaces its splits and keeps its ids', () async {
    final added = await addSyncedExpense();
    await service.updateGroupExpense(
      GroupExpense(
        id: added.id,
        remoteId: 7,
        groupId: groupId,
        payerMemberId: asha,
        amount: 90,
        category: ExpenseCategory.food,
        timestamp: added.timestamp,
        splitType: SplitType.exact,
        splits: [ExpenseSplit(expenseId: 0, memberId: ravi, shareAmount: 90)],
      ),
    );

    final row = (await db.query('group_expenses')).single;
    expect(row['amount'], 90.0);
    expect(row['remote_id'], 7);
    expect(row['is_synced'], 0);
    final splits = await db.query('group_expense_splits');
    expect(splits.map((s) => s['member_id']), [ravi]);

    final balances = await service.getBalances(groupId);
    expect(
      {for (final b in balances) b.username: b.balance},
      {'asha': 90.0, 'ravi': -90.0},
    );
  });

  test(
    'deleting a synced expense or payment queues the server delete',
    () async {
      final added = await addSyncedExpense();
      await service.recordSettlement(
        Settlement(
          groupId: groupId,
          fromMemberId: ravi,
          toMemberId: asha,
          amount: 50,
          timestamp: DateTime(2026, 10, 21),
        ),
      );
      final settlementId = (await db.query('settlements')).single['id'] as int;
      await db.update('settlements', {'remote_id': 3, 'is_synced': 1});

      await service.deleteGroupExpense(added.id!);
      await service.deleteSettlement(settlementId);

      expect(await db.query('group_expenses'), isEmpty);
      expect(await db.query('group_expense_splits'), isEmpty);
      expect(await db.query('settlements'), isEmpty);
      expect(await queuedPaths(), [
        'groups/group-expenses/7/',
        'groups/settlements/3/',
      ]);
    },
  );

  test('deleting an unpushed expense queues nothing', () async {
    final added = await addSyncedExpense();
    await db.update('group_expenses', {'remote_id': null, 'is_synced': 0});
    await service.deleteGroupExpense(added.id!);
    expect(await queuedPaths(), isEmpty);
  });

  test('deleting a group removes everything in it', () async {
    await addSyncedExpense();
    await service.deleteGroup(groupId);

    expect(await db.query('groups'), isEmpty);
    expect(await db.query('group_members'), isEmpty);
    expect(await db.query('group_expenses'), isEmpty);
    expect(await queuedPaths(), ['groups/groups/10/']);
  });
}
