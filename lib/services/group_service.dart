import 'database_service.dart';
import 'sync_service.dart';
import '../models/expenses.dart';

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
        'name': name,
        'icon': icon,
        'created_at': now.toIso8601String(),
        'is_synced': 0,
      });

      await txn.insert('group_members', {
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

    final groups = <Group>[];
    for (final map in groupMaps) {
      groups.add(await _hydrateGroup(map));
    }
    return groups;
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

    final expenses = <GroupExpense>[];
    for (final map in maps) {
      final splitMaps = await db.query(
        'group_expense_splits',
        where: 'expense_id = ?',
        whereArgs: [map['id']],
      );
      final splits = splitMaps.map((s) => ExpenseSplit.fromMap(s)).toList();
      expenses.add(GroupExpense.fromMap(map, splits: splits));
    }
    return expenses;
  }

  /// Add a group expense with pre-computed splits (offline-first).
  Future<GroupExpense> addGroupExpense(GroupExpense expense) async {
    final db = await _dbService.getDatabase();

    final map = expense.toMap();
    map['is_synced'] = 0;
    // The expense and its splits land together: a sync running in between
    // would otherwise push the expense with no splits.
    final expenseId = await db.transaction((txn) async {
      final expenseId = await txn.insert('group_expenses', map);
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
    await db.insert('settlements', map);
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
    final group = await getGroup(groupId);
    final expenses = await getGroupExpenses(groupId);
    final settlements = await getSettlements(groupId);

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
