import 'package:flutter/material.dart';
import '../models/expenses.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _service = GroupService();
  final int? currentUserId;
  final String? currentUsername;

  static const localUsername = 'Me';

  List<Group> _groups = [];
  bool _isLoading = false;

  GroupProvider({this.currentUserId, this.currentUsername}) {
    refreshGroups();
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

  Future<List<MemberBalance>> getBalances(int groupId) {
    return _service.getBalances(groupId);
  }

  /// Net balance for the current user across all groups (positive = owed
  /// to them). Used for an at-a-glance summary on the Events tab.
  Future<double> getMyBalance(int groupId) async {
    final balances = await getBalances(groupId);
    final group = await _service.getGroup(groupId);
    final myMember = group.members
        .where((m) => m.username == (currentUsername ?? localUsername))
        .toList();
    if (myMember.isEmpty) return 0.0;
    final myBalance = balances.where((b) => b.memberId == myMember.first.id);
    return myBalance.isEmpty ? 0.0 : myBalance.first.balance;
  }
}
