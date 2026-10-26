import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/expenses.dart';
import '../providers/app_providers.dart';
import '../providers/group_provider.dart';
import '../widgets/wallet/add_group_expense_sheet.dart';
import '../widgets/wallet/add_member_sheet.dart';
import '../widgets/wallet/settle_up_sheet.dart';
import '../widgets/wallet/balances_list.dart';
import '../widgets/wallet/group_expense_list.dart';
import '../widgets/animated/animated_segmented_tabs.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/ledger_row.dart';

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
  List<Settlement> _settlements = [];
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
    final settlements = await provider.getSettlements(widget.groupId);
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _balances = balances;
      _settlements = settlements;
      _isLoading = false;
    });
  }

  Group? _currentGroup() {
    final groups = ref.watch(groupProviderProvider).groups;
    final match = groups.where((g) => g.id == widget.groupId);
    return match.isEmpty ? null : match.first;
  }

  int? _myMemberId(Group group) {
    // Local mode has no account; the device's member is the 'Me' row.
    final username =
        ref.read(groupProviderProvider).currentUsername ??
        GroupProvider.localUsername;
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
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'edit' ? _editGroup(group) : _deleteGroup(group),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit event')),
              // The server only lets the owner delete a group.
              if (ref.read(groupProviderProvider).isOwner(group))
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete event',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.centeringPadding(context),
                  8,
                  Responsive.centeringPadding(context),
                  // Clear the two stacked FABs (Settle Up, Add Expense).
                  170,
                ),
                children: [
                  _RejectedMembersBanner(
                    names: [
                      for (final m in group.members)
                        if (m.syncError != null) m.username,
                    ],
                  ),
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
                              settlements: _settlements,
                              members: group.members,
                              currentMemberId: myMemberId,
                              onExpenseLongPress: (e) =>
                                  _expenseActions(group, e, myMemberId),
                              onSettlementLongPress: _deleteSettlement,
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
            '${formatRupees(expense.amount)} expense split '
            'between ${expense.splits.length} '
            '${expense.splits.length == 1 ? 'person' : 'people'}.',
          );
        },
      ),
    );
  }

  Future<void> _editGroup(Group group) async {
    final name = TextEditingController(text: group.name);
    final icon = TextEditingController(text: group.icon);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: icon,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final newName = name.text.trim();
    final newIcon = icon.text.trim();
    name.dispose();
    icon.dispose();
    if (saved != true || newName.isEmpty) return;
    await ref
        .read(groupProviderProvider)
        .updateGroup(
          group.id!,
          name: newName,
          icon: newIcon.isEmpty ? null : newIcon,
        );
  }

  Future<void> _deleteGroup(Group group) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete event?',
      message:
          '"${group.name}" and all its expenses and payments will be '
          'deleted for everyone in it.',
    );
    if (!confirmed || !mounted) return;
    final provider = ref.read(groupProviderProvider);
    // This screen is gone after the pop; the navigator's context isn't.
    final navigator = Navigator.of(context);
    navigator.pop();
    AppSnackbar.info(navigator.context, '"${group.name}" deleted.');
    await provider.deleteGroup(group.id!);
  }

  void _expenseActions(Group group, GroupExpense expense, int? myMemberId) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit expense'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditExpenseSheet(group, expense, myMemberId);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete expense',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteExpense(expense);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExpenseSheet(
    Group group,
    GroupExpense expense,
    int? myMemberId,
  ) {
    final provider = ref.read(groupProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGroupExpenseSheet(
        group: group,
        initial: expense,
        defaultPayerMemberId: myMemberId,
        onAdd: (updated) async {
          await provider.updateGroupExpense(updated);
          await _load();
          if (!mounted) return;
          AppSnackbar.success(context, 'Expense updated.');
        },
      ),
    );
  }

  Future<void> _deleteExpense(GroupExpense expense) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete expense?',
      message:
          '${formatRupees(expense.amount)} '
          '"${expense.description ?? expense.category.displayName}" '
          'will be removed and balances updated.',
    );
    if (!confirmed) return;
    await ref.read(groupProviderProvider).deleteGroupExpense(expense.id!);
    await _load();
  }

  Future<void> _deleteSettlement(Settlement settlement) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete payment?',
      message:
          'This ${formatRupees(settlement.amount)} payment will be removed '
          'and balances updated.',
    );
    if (!confirmed) return;
    await ref.read(groupProviderProvider).deleteSettlement(settlement.id!);
    await _load();
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
        onSettle: (fromMemberId, toMemberId, amount) async {
          await provider.recordSettlement(
            Settlement(
              groupId: widget.groupId,
              fromMemberId: fromMemberId,
              toMemberId: toMemberId,
              amount: amount,
              timestamp: DateTime.now(),
            ),
          );
          await _load();
          if (!mounted) return;
          AppSnackbar.success(
            this.context,
            'Settlement of ${formatRupees(amount)} recorded.',
          );
        },
      ),
    );
  }
}

/// Explains why expenses with people the server refused (no TrackIt
/// account) stay on this device instead of syncing.
class _RejectedMembersBanner extends StatelessWidget {
  final List<String> names;
  const _RejectedMembersBanner({required this.names});

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final who = names.join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              names.length == 1
                  ? "$who doesn't have a TrackIt account, so expenses "
                        'shared with them stay on this device.'
                  : "$who don't have TrackIt accounts, so expenses "
                        'shared with them stay on this device.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
