import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../models/expenses.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/wallet/add_group_expense_sheet.dart';
import '../widgets/wallet/add_member_sheet.dart';
import '../widgets/wallet/settle_up_sheet.dart';
import '../widgets/wallet/balances_list.dart';
import '../widgets/wallet/group_expense_list.dart';
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final myMemberId = _myMemberId(group);
    // Offline an event only groups your own spending; members, splits and
    // settling up need an account.
    final shared =
        ref.watch(authProvider).state.status == AuthStatus.authenticated;
    final showBalances = shared && _tabIndex == 1;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (shared)
            IconButton(
              tooltip: 'Add member',
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
                    style: TextStyle(color: AppColors.expense),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  Responsive.centeringPadding(context),
                  8,
                  Responsive.centeringPadding(context),
                  // Clear the add-expense FAB.
                  100,
                ),
                children: [
                  _RejectedMembersBanner(
                    names: [
                      for (final m in group.members)
                        if (m.syncError != null) m.username,
                    ],
                    onAddAsGuests: () => _addRejectedAsGuests(group),
                  ),
                  _GroupHeader(
                    group: group,
                    shared: shared,
                    totalSpent: _expenses.fold(0.0, (t, e) => t + e.amount),
                    myBalance: _balances
                        .where((b) => b.memberId == myMemberId)
                        .firstOrNull
                        ?.balance,
                    showingBalances: showBalances,
                    onSettleUp: myMemberId == null
                        ? null
                        : () => _showSettleUpSheet(context, group, myMemberId),
                    onToggleBalances: () =>
                        setState(() => _tabIndex = _tabIndex == 1 ? 0 : 1),
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
                    child: !showBalances
                        ? KeyedSubtree(
                            key: const ValueKey('expenses'),
                            child: GroupExpenseList(
                              expenses: _expenses,
                              settlements: _settlements,
                              members: group.members,
                              currentMemberId: myMemberId,
                              shared: shared,
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
                              guestIds: {
                                for (final m in group.members)
                                  if (m.isGuest) m.id!,
                              },
                              onLinkGuest: (id) => _linkGuest(
                                group.members.firstWhere((m) => m.id == id),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_expense',
        onPressed: () => _showAddExpenseSheet(context, group, myMemberId),
        tooltip: 'Add expense',
        child: const Icon(Icons.add),
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
        shared: ref.read(authProvider).state.status == AuthStatus.authenticated,
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
                color: AppColors.expense,
              ),
              title: const Text(
                'Delete expense',
                style: TextStyle(color: AppColors.expense),
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
        shared: ref.read(authProvider).state.status == AuthStatus.authenticated,
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
        onAdd: (name, {required guest}) async {
          await provider.addMember(widget.groupId, name, guest: guest);
          await _load();
          if (!mounted) return;
          AppSnackbar.success(
            this.context,
            guest
                ? '$name added. Link them to their account from Balances '
                      'if they join TrackIt.'
                : '$name added. They will see this event once synced.',
          );
        },
      ),
    );
  }

  Future<void> _addRejectedAsGuests(Group group) async {
    await ref.read(groupProviderProvider).addRejectedAsGuests(group.id!);
    await _load();
    if (mounted) {
      AppSnackbar.success(
        context,
        'Added as guests. Their expenses will sync now.',
      );
    }
  }

  /// A guest joined TrackIt: attach their account so the event and their
  /// share show up for them.
  Future<void> _linkGuest(GroupMember guest) async {
    final controller = TextEditingController();
    String? error;
    final linked = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text('Link ${guest.username} to an account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If ${guest.username} has joined TrackIt, enter their '
                'username. They keep everything already shared with them.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Their username',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final username = controller.text.trim();
                if (username.isEmpty) return;
                try {
                  await ref
                      .read(groupProviderProvider)
                      .linkGuest(guest, username);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } on StateError catch (e) {
                  setDialog(() => error = e.message);
                }
              },
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (linked == true) {
      await _load();
      if (mounted) AppSnackbar.success(context, 'Account linked.');
    }
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
  final VoidCallback onAddAsGuests;
  const _RejectedMembersBanner({
    required this.names,
    required this.onAddAsGuests,
  });

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names.length == 1
                      ? "$who doesn't have a TrackIt account, so expenses "
                            'shared with them stay on this device. Add them '
                            'by name instead to sync.'
                      : "$who don't have TrackIt accounts, so expenses "
                            'shared with them stay on this device. Add them '
                            'by name instead to sync.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: onAddAsGuests,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    names.length == 1 ? 'Add by name' : 'Add them by name',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Splitwise-style event header: emoji tile and name, what the event
/// means for you overall, and the Settle up / Balances actions.
class _GroupHeader extends StatelessWidget {
  final Group group;

  /// False offline: show what was spent, not balances or settling up.
  final bool shared;
  final double totalSpent;

  /// Your net balance here; null while unknown or not a member.
  final double? myBalance;
  final bool showingBalances;
  final VoidCallback? onSettleUp;
  final VoidCallback onToggleBalances;

  const _GroupHeader({
    required this.group,
    required this.shared,
    required this.totalSpent,
    required this.myBalance,
    required this.showingBalances,
    required this.onSettleUp,
    required this.onToggleBalances,
  });

  @override
  Widget build(BuildContext context) {
    final balance = myBalance ?? 0;
    final settled = balance.abs() < 0.01;
    final color = settled
        ? AppColors.textSecondary
        : balance > 0
        ? AppColors.income
        : AppColors.outflow;
    final members = group.members.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(group.icon, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppTextStyles.h2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shared
                        ? '$members member${members == 1 ? '' : 's'}'
                        : 'Just you · on this phone',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!shared) ...[
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(
                  text: formatRupees(totalSpent),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' spent in this event'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sign in to add friends and split costs.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ] else ...[
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodyLg.copyWith(color: color),
              children: settled
                  ? const [TextSpan(text: 'You are all settled up here')]
                  : [
                      TextSpan(
                        text: balance > 0 ? 'You are owed ' : 'You owe ',
                      ),
                      TextSpan(
                        text: formatRupees(balance.abs()),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' overall'),
                    ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: onSettleUp,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.outflow,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text('Settle up'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onToggleBalances,
                icon: Icon(
                  showingBalances
                      ? Icons.receipt_long_outlined
                      : Icons.balance_rounded,
                  size: 18,
                ),
                label: Text(showingBalances ? 'Expenses' : 'Balances'),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
