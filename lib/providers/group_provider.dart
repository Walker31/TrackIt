import 'dart:async';
import 'package:flutter/material.dart';
import '../models/expenses.dart';
import '../services/group_service.dart';
import '../services/sync_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _service = GroupService();
  final int? currentUserId;
  final String? currentUsername;

  static const localUsername = 'Me';

  List<Group> _groups = [];
  bool _isLoading = false;

  StreamSubscription<void>? _syncSub;

  GroupProvider({this.currentUserId, this.currentUsername}) {
    // Pick up groups and members pulled by background syncs.
    _syncSub = SyncService().onSyncComplete.listen((_) => refreshGroups());
    refreshGroups();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;

  Future<void> refreshGroups() async {
    _isLoading = true;
    notifyListeners();
    try {
      _groups = await _service.getAllGroups();
    } catch (e) {
      debugPrint('Error refreshing groups: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Settlement>> getSettlements(int groupId) =>
      _service.getSettlements(groupId);

  Future<void> createGroup(String name, String icon) async {
    // Local mode has no account: the creator is just "Me" on this device.
    await _service.createGroup(
      name: name,
      icon: icon,
      currentUserId: currentUserId ?? 0,
      currentUsername: currentUsername ?? localUsername,
    );
    await refreshGroups();
  }

  Future<void> addMember(int groupId, String username) async {
    await _service.addMember(groupId, username);
    await refreshGroups();
  }

  Future<List<GroupExpense>> getGroupExpenses(int groupId) {
    return _service.getGroupExpenses(groupId);
  }

  Future<GroupExpense> addGroupExpense(GroupExpense expense) async {
    final result = await _service.addGroupExpense(expense);
    await refreshGroups();
    return result;
  }

  Future<void> recordSettlement(Settlement settlement) async {
    await _service.recordSettlement(settlement);
    await refreshGroups();
  }

  Future<void> updateGroup(int groupId, {String? name, String? icon}) async {
    await _service.updateGroup(groupId, name: name, icon: icon);
    await refreshGroups();
  }

  Future<void> deleteGroup(int groupId) async {
    await _service.deleteGroup(groupId);
    await refreshGroups();
  }

  Future<void> updateGroupExpense(GroupExpense expense) async {
    await _service.updateGroupExpense(expense);
    await refreshGroups();
  }

  Future<void> deleteGroupExpense(int expenseId) async {
    await _service.deleteGroupExpense(expenseId);
    await refreshGroups();
  }

  Future<void> deleteSettlement(int settlementId) async {
    await _service.deleteSettlement(settlementId);
    await refreshGroups();
  }

  /// Whether the viewer owns [group] (only owners may delete it).
  bool isOwner(Group group) => group.members.any(
    (m) =>
        m.role == 'owner' && m.username == (currentUsername ?? localUsername),
  );

  Future<List<MemberBalance>> getBalances(int groupId) {
    return _service.getBalances(groupId);
  }

  /// Net balance for the current user across all groups (positive = owed
  /// to them). Used for an at-a-glance summary on the Events tab.
  Future<double> getMyBalance(int groupId) async {
    // Balances already carry each member's username; no second group read.
    final me = currentUsername ?? localUsername;
    final balances = await getBalances(groupId);
    return balances.where((b) => b.username == me).firstOrNull?.balance ?? 0.0;
  }
}
