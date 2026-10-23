import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/expenses.dart';
import '../providers/app_providers.dart';
import '../widgets/wallet/add_group_expense_sheet.dart';
import '../widgets/wallet/add_member_sheet.dart';
import '../widgets/wallet/settle_up_sheet.dart';
import '../widgets/wallet/balances_list.dart';
import '../widgets/wallet/group_expense_list.dart';
import '../widgets/animated/animated_segmented_tabs.dart';
import '../widgets/app_snackbar.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final int groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _tabIndex = 0;
  List<GroupExpense> _expenses = [];
  List<MemberBalance> _balances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = ref.read(groupProviderProvider);
    setState(() => _isLoading = true);
    final expenses = await provider.getGroupExpenses(widget.groupId);
    final balances = await provider.getBalances(widget.groupId);
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _balances = balances;
      _isLoading = false;
    });
  }

  Group? _currentGroup() {
    final groups = ref.watch(groupProviderProvider).groups;
    final match = groups.where((g) => g.id == widget.groupId);
    return match.isEmpty ? null : match.first;
  }

  int? _myMemberId(Group group) {
    final username = ref.read(groupProviderProvider).currentUsername;
    final match = group.members.where((m) => m.username == username);
    return match.isEmpty ? null : match.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final group = _currentGroup();

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myMemberId = _myMemberId(group);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(group.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(group.name, style: AppTextStyles.h3),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: () => _showAddMemberSheet(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  AnimatedSegmentedTabs(
                    labels: const ["Expenses", "Balances"],
                    selectedIndex: _tabIndex,
                    onChanged: (index) => setState(() => _tabIndex = index),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _tabIndex == 0
                        ? KeyedSubtree(
                            key: const ValueKey('expenses'),
                            child: GroupExpenseList(
                              expenses: _expenses,
                              members: group.members,
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('balances'),
                            child: BalancesList(
                              balances: _balances,
                              currentMemberId: myMemberId ?? -1,
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'settle_up',
            onPressed: myMemberId == null
                ? null
                : () => _showSettleUpSheet(context, group, myMemberId),
            backgroundColor: AppColors.income,
            icon: const Icon(Icons.handshake_outlined),
            label: const Text("Settle Up"),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_expense',
            onPressed: () => _showAddExpenseSheet(context, group, myMemberId),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text("Add Expense"),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(
    BuildContext context,
    Group group,
    int? myMemberId,
  ) {
    final provider = ref.read(groupProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGroupExpenseSheet(
        group: group,
        defaultPayerMemberId: myMemberId,
        onAdd: (expense) async {
          await provider.addGroupExpense(expense);
          await _load();
          if (!mounted) return;
          AppSnackbar.success(
            this.context,
            '₹${expense.amount.toStringAsFixed(0)} expense split '
            'between ${expense.splits.length} '
            '${expense.splits.length == 1 ? 'person' : 'people'}.',
          );
        },
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    final provider = ref.read(groupProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMemberSheet(
        onAdd: (username) async {
          await provider.addMember(widget.groupId, username);
          await _load();
          if (!mounted) return;
          AppSnackbar.success(
            this.context,
            '$username added. They will see this event once synced.',
          );
        },
      ),
    );
  }

  void _showSettleUpSheet(BuildContext context, Group group, int myMemberId) {
    final provider = ref.read(groupProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettleUpSheet(
        currentMemberId: myMemberId,
        members: group.members,
        balances: _balances,
        onSettle: (toMemberId, amount) async {
          await provider.recordSettlement(
            Settlement(
              groupId: widget.groupId,
              fromMemberId: myMemberId,
              toMemberId: toMemberId,
              amount: amount,
              timestamp: DateTime.now(),
            ),
          );
          await _load();
          if (!mounted) return;
          AppSnackbar.success(
            this.context,
            'Settlement of ₹${amount.toStringAsFixed(0)} recorded.',
          );
        },
      ),
    );
  }
}
