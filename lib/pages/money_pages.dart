import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../services/id_generator.dart';
import '../services/money_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';

Widget _constrained(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: child,
  ),
);

final _moneyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
final _signedMoneyFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9.\-]'),
);

/// "₹1,200" or "−₹1,200".
String signedRupees(double v) =>
    v < 0 ? '−${formatRupees(v.abs())}' : formatRupees(v);

// ---------------------------------------------------------------------------
// Accounts

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  late Future<List<AccountBalance>> _balances = AccountService().balances();

  void _reload() => setState(() => _balances = AccountService().balances());

  Future<void> _editAccount([Account? existing]) async {
    final saved = await showDialog<Account>(
      context: context,
      builder: (_) => _AccountDialog(existing: existing),
    );
    if (saved == null) return;
    await AccountService().save(saved);
    _reload();
    if (!mounted) return;
    AppSnackbar.success(
      context,
      existing == null ? '${saved.name} added.' : '${saved.name} updated.',
    );
  }

  Future<void> _archive(Account a) async {
    await AccountService().save(a.copyWith(archived: true));
    _reload();
    if (!mounted) return;
    AppSnackbar.info(
      context,
      '${a.name} hidden. Its transactions are kept.',
      actionLabel: 'Undo',
      onAction: () async {
        await AccountService().save(a);
        _reload();
      },
    );
  }

  Future<void> _transfer(List<AccountBalance> balances) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _TransferDialog(accounts: [for (final b in balances) b.account]),
    );
    if (done == true) {
      _reload();
      if (mounted) AppSnackbar.success(context, 'Transfer saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expenseProviderProvider, (_, _) => _reload());
    return FutureBuilder<List<AccountBalance>>(
      future: _balances,
      builder: (context, snap) {
        final balances = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Accounts'),
            actions: [
              if (balances != null && balances.length >= 2)
                TextButton.icon(
                  onPressed: () => _transfer(balances),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer'),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _editAccount,
            icon: const Icon(Icons.add),
            label: const Text('Add account'),
          ),
          body: balances == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: [
                    _constrained(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (balances.isEmpty)
                            const EmptyState(
                              card: true,
                              icon: Icons.account_balance_rounded,
                              title: 'No accounts yet',
                              message:
                                  'Add your bank account, cash and cards with '
                                  'what is in them today. Pick one when you '
                                  'add a transaction and its balance follows.',
                            )
                          else ...[
                            _Total(balances: balances),
                            const SizedBox(height: 12),
                            for (final b in balances)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AccountTile(
                                  balance: b,
                                  onOpen: () => context.push(
                                    '/transactions?account=${b.account.id}',
                                  ),
                                  onEdit: () => _editAccount(b.account),
                                  onArchive: () => _archive(b.account),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Transactions without an account still count '
                                'in your spending, just not in a balance.',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  final List<AccountBalance> balances;
  const _Total({required this.balances});

  @override
  Widget build(BuildContext context) {
    final total = balances.fold<double>(0, (a, b) => a + b.balance);
    final owed = balances
        .where((b) => b.balance < 0)
        .fold<double>(0, (a, b) => a + b.balance);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET BALANCE', style: AppTextStyles.overline),
          const SizedBox(height: 6),
          Text(
            signedRupees(total),
            style: AppTextStyles.h1.copyWith(
              color: total < 0 ? AppColors.outflow : AppColors.textPrimary,
            ),
          ),
          if (owed < 0)
            Text(
              'Including ${formatRupees(owed.abs())} owed on cards',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountBalance balance;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _AccountTile({
    required this.balance,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final a = balance.account;
    final v = balance.balance;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(a.kind.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      a.kind == AccountKind.card && v < 0
                          ? '${a.kind.label} · owed'
                          : a.kind.label,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                signedRupees(v),
                style: AppTextStyles.bodyLg.copyWith(
                  fontWeight: FontWeight.w700,
                  color: v < 0 ? AppColors.outflow : AppColors.textPrimary,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options for ${a.name}',
                onSelected: (v) => v == 'edit' ? onEdit() : onArchive(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Hide account')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final Account? existing;
  const _AccountDialog({this.existing});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _opening = TextEditingController(
    text: widget.existing == null
        ? ''
        : _plain(
            widget.existing!.kind == AccountKind.card
                ? -widget.existing!.openingBalance
                : widget.existing!.openingBalance,
          ),
  );
  late AccountKind _kind = widget.existing?.kind ?? AccountKind.bank;
  String? _error;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final raw = _opening.text.trim();
    final value = raw.isEmpty ? 0.0 : double.tryParse(raw);
    if (name.isEmpty) {
      setState(() => _error = 'Give the account a name.');
      return;
    }
    if (value == null) {
      setState(() => _error = 'Enter the balance as a number.');
      return;
    }
    // For a card the user types what's owed; it's stored as negative.
    final opening = _kind == AccountKind.card ? -value.abs() : value;
    final existing = widget.existing;
    Navigator.pop(
      context,
      existing == null
          ? Account.create(name, _kind, opening)
          : existing.copyWith(name: name, kind: _kind, openingBalance: opening),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _kind == AccountKind.card;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add account' : 'Edit account'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. HDFC savings',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in AccountKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 16),
                    label: Text(k.label),
                    selected: _kind == k,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [card ? _moneyFormatter : _signedMoneyFormatter],
              decoration: InputDecoration(
                labelText: card ? 'Owed on it today' : 'Balance today',
                prefixText: '₹ ',
                helperText: widget.existing == null
                    ? 'Transactions you add from now on change it.'
                    : 'Changing this shifts the balance by the same amount.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final List<Account> accounts;
  const _TransferDialog({required this.accounts});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late String _from = widget.accounts.first.id;
  late String _to = widget.accounts[1].id;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text);
    if (_from == _to) {
      setState(() => _error = 'Pick two different accounts.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    await AccountService().transfer(
      from: _from,
      to: _to,
      amount: amount,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  DropdownButtonFormField<String> _picker(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final a in widget.accounts)
        DropdownMenuItem(value: a.id, child: Text(a.name)),
    ],
    onChanged: (v) {
      if (v != null) setState(() => onChanged(v));
    },
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Moving money between your own accounts, like paying a card '
              'bill or withdrawing cash. It does not count as spending.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _picker('From', _from, (v) => _from = v),
            const SizedBox(height: 12),
            _picker('To', _to, (v) => _to = v),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_moneyFormatter],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Transfer')),
      ],
    );
  }
}

/// Wallet card: net balance and each account, linking to Accounts.
class AccountsCard extends ConsumerStatefulWidget {
  const AccountsCard({super.key});

  @override
  ConsumerState<AccountsCard> createState() => _AccountsCardState();
}

class _AccountsCardState extends ConsumerState<AccountsCard> {
  late Future<List<AccountBalance>> _balances = AccountService().balances();

  @override
  Widget build(BuildContext context) {
    ref.listen(
      expenseProviderProvider,
      (_, _) => setState(() => _balances = AccountService().balances()),
    );
    return FutureBuilder<List<AccountBalance>>(
      future: _balances,
      builder: (context, snap) {
        final balances = snap.data ?? const <AccountBalance>[];
        final total = balances.fold<double>(0, (a, b) => a + b.balance);
        return AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await context.push('/accounts');
              if (mounted) {
                setState(() => _balances = AccountService().balances());
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Accounts', style: AppTextStyles.h3),
                      ),
                      if (balances.isNotEmpty)
                        Text(
                          signedRupees(total),
                          style: AppTextStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (balances.isEmpty)
                    Text(
                      'Add your bank, cash and cards to see what is in each.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    for (final b in balances.take(4))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              b.account.kind.icon,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.account.name,
                                style: AppTextStyles.bodyMd,
                              ),
                            ),
                            Text(
                              signedRupees(b.balance),
                              style: AppTextStyles.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                                color: b.balance < 0
                                    ? AppColors.outflow
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Savings goals

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late Future<List<Goal>> _goals = GoalService().goals();

  void _reload() => setState(() => _goals = GoalService().goals());

  Future<void> _edit([Goal? existing]) async {
    final saved = await showDialog<Goal>(
      context: context,
      builder: (_) => _GoalDialog(existing: existing),
    );
    if (saved == null) return;
    await GoalService().save(saved);
    _reload();
  }

  Future<void> _move(Goal goal, {required bool add}) async {
    final amount = await _askAmount(
      context,
      title: add ? 'Add to ${goal.name}' : 'Take out of ${goal.name}',
      max: add ? null : goal.saved,
    );
    if (amount == null) return;
    await GoalService().contribute(goal.id, add ? amount : -amount);
    _reload();
    if (!mounted) return;
    final reachedNow =
        add && goal.saved < goal.target && goal.saved + amount >= goal.target;
    AppSnackbar.success(
      context,
      reachedNow
          ? 'Goal reached: ${goal.name}!'
          : add
          ? '${formatRupees(amount)} put towards ${goal.name}.'
          : '${formatRupees(amount)} taken out of ${goal.name}.',
    );
  }

  Future<void> _delete(Goal goal) async {
    final contributions = await GoalService().contributions(goal.id);
    await GoalService().delete(goal.id);
    _reload();
    if (!mounted) return;
    AppSnackbar.info(
      context,
      '${goal.name} deleted.',
      actionLabel: 'Undo',
      onAction: () async {
        await GoalService().save(goal);
        for (final c in contributions) {
          await GoalService().contribute(
            goal.id,
            (c['amount'] as num).toDouble(),
            on: DateTime.parse(c['date'] as String),
            note: c['note'] as String?,
          );
        }
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: FutureBuilder<List<Goal>>(
        future: _goals,
        builder: (context, snap) {
          final goals = snap.data;
          if (goals == null) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              _constrained(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (goals.isEmpty)
                      const EmptyState(
                        card: true,
                        icon: Icons.flag_outlined,
                        title: 'No goals yet',
                        message:
                            'Saving for a trip, a phone or a rainy day? Set an '
                            'amount and a date and see how much to put aside '
                            'each month.',
                      ),
                    for (final g in goals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GoalTile(
                          goal: g,
                          onAdd: () => _move(g, add: true),
                          onTakeOut: g.saved > 0
                              ? () => _move(g, add: false)
                              : null,
                          onEdit: () => _edit(g),
                          onDelete: () => _delete(g),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<double?> _askAmount(
  BuildContext context, {
  required String title,
  double? max,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_moneyFormatter],
        decoration: InputDecoration(
          prefixText: '₹ ',
          helperText: max == null ? null : 'Up to ${formatRupees(max)}',
        ),
        onSubmitted: (v) => Navigator.pop(context, double.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, double.tryParse(controller.text)),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value == null || value <= 0) return null;
  if (max != null && value > max + 0.001) {
    if (context.mounted) {
      AppSnackbar.error(
        context,
        'Only ${formatRupees(max)} is saved in this goal.',
      );
    }
    return null;
  }
  return value;
}

class GoalTile extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onAdd;
  final VoidCallback? onTakeOut;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool compact;

  const GoalTile({
    super.key,
    required this.goal,
    this.onAdd,
    this.onTakeOut,
    this.onEdit,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final needed = monthlyNeeded(g);
    final color = g.reached ? AppColors.income : AppColors.primary;
    final date = g.targetDate;
    final overdue = date != null && !g.reached && date.isBefore(DateTime.now());
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                g.reached ? Icons.emoji_events_rounded : Icons.flag_rounded,
                color: g.reached ? AppColors.accent : color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.name,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onEdit != null || onDelete != null || onTakeOut != null)
                PopupMenuButton<String>(
                  tooltip: 'Options for ${g.name}',
                  onSelected: (v) => switch (v) {
                    'out' => onTakeOut?.call(),
                    'edit' => onEdit?.call(),
                    _ => onDelete?.call(),
                  },
                  itemBuilder: (_) => [
                    if (onTakeOut != null)
                      const PopupMenuItem(
                        value: 'out',
                        child: Text('Take money out'),
                      ),
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                )
              else
                const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label:
                  '${g.name}: ${formatRupees(g.saved)} of '
                  '${formatRupees(g.target)} saved',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatRupees(g.saved)} of '
                          '${formatRupees(g.target)}',
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(g.progress * 100).floor()}%',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              g.reached
                  ? 'Reached. Well done!'
                  : overdue
                  ? 'Target date passed · ${formatRupees(g.remaining)} to go'
                  : needed != null
                  ? '${formatRupees(needed)} a month to reach it by '
                        '${DateFormat('MMM yyyy').format(date!)}'
                  : '${formatRupees(g.remaining)} to go',
              style: AppTextStyles.bodySm.copyWith(
                color: overdue ? AppColors.outflow : AppColors.textSecondary,
              ),
            ),
          ],
          if (onAdd != null && !g.reached)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add money'),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  final Goal? existing;
  const _GoalDialog({this.existing});

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.target.toStringAsFixed(0),
  );
  late DateTime? _date = widget.existing?.targetDate;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30),
      initialDate: _date ?? DateTime(now.year, now.month + 6, now.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final name = _name.text.trim();
    final target = double.tryParse(_target.text);
    if (name.isEmpty) {
      setState(() => _error = 'Name the goal.');
      return;
    }
    if (target == null || target <= 0) {
      setState(() => _error = 'Enter the amount you want to save.');
      return;
    }
    final e = widget.existing;
    Navigator.pop(
      context,
      Goal(
        id: e?.id ?? IdGenerator.uuid(),
        name: name,
        target: target,
        targetDate: _date,
        saved: e?.saved ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New goal' : 'Edit goal'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What for?',
                hintText: 'e.g. Goa trip, new phone',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_moneyFormatter],
              decoration: const InputDecoration(
                labelText: 'Amount to save',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(
                      _date == null
                          ? 'By a date (optional)'
                          : 'By ${DateFormat('d MMM yyyy').format(_date!)}',
                    ),
                  ),
                ),
                if (_date != null)
                  IconButton(
                    tooltip: 'No date',
                    onPressed: () => setState(() => _date = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Today card: the goals in progress, or a nudge to start one.
class GoalsCard extends StatefulWidget {
  const GoalsCard({super.key});

  @override
  State<GoalsCard> createState() => _GoalsCardState();
}

class _GoalsCardState extends State<GoalsCard> {
  late Future<List<Goal>> _goals = GoalService().goals();

  Future<void> _open() async {
    await context.push('/goals');
    if (mounted) setState(() => _goals = GoalService().goals());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Goal>>(
      future: _goals,
      builder: (context, snap) {
        final goals = (snap.data ?? const <Goal>[])
            .where((g) => !g.reached)
            .toList();
        if (goals.isEmpty) {
          return AppCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Savings goals',
                            style: AppTextStyles.bodyLg.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Save towards a trip, a phone or a rainy day',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _open,
          child: Column(
            children: [
              for (final g in goals.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GoalTile(goal: g, compact: true),
                ),
            ],
          ),
        );
      },
    );
  }
}
