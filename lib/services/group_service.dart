import 'database_service.dart';
import 'sync_outbox.dart';
import 'sync_service.dart';
import '../models/expenses.dart';
import 'id_generator.dart';

class GroupService {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();

  /// Create a group locally (offline-first) with the creator as owner.
  Future<Group> createGroup({
    required String name,
    required String icon,
    required int currentUserId,
    required String currentUsername,
  }) async {
    final db = await _dbService.getDatabase();
    final now = DateTime.now();

    // One transaction, so a sync can't push the group before its owner row
    // exists (the server would then create a second owner).
    final groupId = await db.transaction((txn) async {
      final groupId = await txn.insert('groups', {
        'uuid': IdGenerator.uuid(),
        'name': name,
        'icon': icon,
        'created_at': now.toIso8601String(),
        'is_synced': 0,
      });

      await txn.insert('group_members', {
        'uuid': IdGenerator.uuid(),
        'group_id': groupId,
        'user_id': currentUserId,
        'username': currentUsername,
        'role': 'owner',
        'is_synced': 0,
      });
      return groupId;
    });

    _syncService.performSync();

    return getGroup(groupId);
  }

  /// Queue adding an existing user (by username) to a group. Requires the
  /// group to eventually sync before the invite reaches the server.
  Future<void> addMember(int groupId, String username) async {
    final db = await _dbService.getDatabase();

    final existing = await db.query(
      'group_members',
      where: 'group_id = ? AND username = ?',
      whereArgs: [groupId, username],
    );
    if (existing.isNotEmpty) {
      throw StateError('$username is already a member of this group.');
    }

    await db.insert('group_members', {
      'uuid': IdGenerator.uuid(),
      'group_id': groupId,
      'username': username,
      'role': 'member',
      'is_synced': 0,
    });

    _syncService.performSync();
  }

  Future<List<Group>> getAllGroups() async {
    final db = await _dbService.getDatabase();
    final groupMaps = await db.query('groups', orderBy: 'created_at DESC');

    // One query for every group's members rather than one per group.
    final membersByGroup = <Object?, List<GroupMember>>{};
    for (final m in await db.query('group_members')) {
      (membersByGroup[m['group_id']] ??= []).add(GroupMember.fromMap(m));
    }
    return [
      for (final map in groupMaps)
        Group.fromMap(map, members: membersByGroup[map['id']] ?? []),
    ];
  }

  Future<Group> getGroup(int groupId) async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );
    return _hydrateGroup(maps.first);
  }

  Future<Group> _hydrateGroup(Map<String, dynamic> map) async {
    final db = await _dbService.getDatabase();
    final memberMaps = await db.query(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [map['id']],
    );
    final members = memberMaps.map((m) => GroupMember.fromMap(m)).toList();
    return Group.fromMap(map, members: members);
  }

  Future<List<GroupExpense>> getGroupExpenses(int groupId) async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'group_expenses',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'timestamp DESC',
    );

    // Every split in the group in one query, rather than one per expense.
    final splitMaps = await db.rawQuery(
      'SELECT s.* FROM group_expense_splits s '
      'JOIN group_expenses e ON e.id = s.expense_id WHERE e.group_id = ?',
      [groupId],
    );
    final splitsByExpense = <Object?, List<ExpenseSplit>>{};
    for (final s in splitMaps) {
      (splitsByExpense[s['expense_id']] ??= []).add(ExpenseSplit.fromMap(s));
    }
    return [
      for (final map in maps)
        GroupExpense.fromMap(map, splits: splitsByExpense[map['id']] ?? []),
    ];
  }

  /// Add a group expense with pre-computed splits (offline-first).
  Future<GroupExpense> addGroupExpense(GroupExpense expense) async {
    final db = await _dbService.getDatabase();

    final map = expense.toMap();
    map['is_synced'] = 0;
    // The expense and its splits land together: a sync running in between
    // would otherwise push the expense with no splits.
    final expenseId = await db.transaction((txn) async {
      final expenseId = await txn.insert('group_expenses', {
        ...map,
        'uuid': IdGenerator.uuid(),
      });
      for (final split in expense.splits) {
        await txn.insert('group_expense_splits', {
          'expense_id': expenseId,
          'member_id': split.memberId,
          'share_amount': split.shareAmount,
        });
      }
      return expenseId;
    });

    _syncService.performSync();

    final splitMaps = await db.query(
      'group_expense_splits',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return expense.copyWith(
      id: expenseId,
      splits: splitMaps.map((s) => ExpenseSplit.fromMap(s)).toList(),
    );
  }

  Future<void> recordSettlement(Settlement settlement) async {
    final db = await _dbService.getDatabase();
    final map = settlement.toMap();
    map['is_synced'] = 0;
    await db.insert('settlements', {...map, 'uuid': IdGenerator.uuid()});
    _syncService.performSync();
  }

  /// Rename a group or change its icon.
  Future<void> updateGroup(int groupId, {String? name, String? icon}) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'groups',
      {'name': ?name, 'icon': ?icon, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [groupId],
    );
    _syncService.performSync();
  }

  /// Delete a group with everything in it. On the server only the owner
  /// may do this, so callers should offer it to the owner only.
  Future<void> deleteGroup(int groupId) =>
      _deleteRow('groups', groupId, 'groups/groups/');

  /// Replace an expense's fields and splits.
  Future<void> updateGroupExpense(GroupExpense expense) async {
    final db = await _dbService.getDatabase();
    final map = expense.toMap()
      ..remove('id')
      ..remove('remote_id')
      ..['is_synced'] = 0;
    await db.transaction((txn) async {
      await txn.update(
        'group_expenses',
        map,
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      await txn.delete(
        'group_expense_splits',
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      for (final split in expense.splits) {
        await txn.insert('group_expense_splits', {
          'expense_id': expense.id,
          'member_id': split.memberId,
          'share_amount': split.shareAmount,
        });
      }
    });
    _syncService.performSync();
  }

  Future<void> deleteGroupExpense(int expenseId) =>
      _deleteRow('group_expenses', expenseId, 'groups/group-expenses/');

  Future<void> deleteSettlement(int settlementId) =>
      _deleteRow('settlements', settlementId, 'groups/settlements/');

  /// Delete a local row (children cascade), queueing the server delete if
  /// it was ever pushed.
  Future<void> _deleteRow(String table, int id, String remotePath) async {
    final db = await _dbService.getDatabase();
    await db.transaction((txn) async {
      final rows = await txn.query(
        table,
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty && rows.first['remote_id'] != null) {
        await SyncOutbox.enqueueDelete(
          txn,
          '$remotePath${rows.first['remote_id']}/',
        );
      }
      await txn.delete(table, where: 'id = ?', whereArgs: [id]);
    });
    _syncService.performSync();
  }

  Future<List<Settlement>> getSettlements(int groupId) async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'settlements',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => Settlement.fromMap(m)).toList();
  }

  /// Net balance per member: positive = the group owes them, negative =
  /// they owe the group. Mirrors the server's `balances` calculation so
  /// both sides always agree.
  Future<List<MemberBalance>> getBalances(int groupId) async {
    final (group, expenses, settlements) = await (
      getGroup(groupId),
      getGroupExpenses(groupId),
      getSettlements(groupId),
    ).wait;

    final balances = <int, double>{for (final m in group.members) m.id!: 0.0};

    for (final expense in expenses) {
      balances[expense.payerMemberId] =
          (balances[expense.payerMemberId] ?? 0.0) + expense.amount;
      for (final split in expense.splits) {
        balances[split.memberId] =
            (balances[split.memberId] ?? 0.0) - split.shareAmount;
      }
    }

    for (final settlement in settlements) {
      balances[settlement.fromMemberId] =
          (balances[settlement.fromMemberId] ?? 0.0) + settlement.amount;
      balances[settlement.toMemberId] =
          (balances[settlement.toMemberId] ?? 0.0) - settlement.amount;
    }

    return group.members
        .map(
          (m) => MemberBalance(
            memberId: m.id!,
            username: m.username,
            balance: balances[m.id!] ?? 0.0,
          ),
        )
        .toList();
  }
}
