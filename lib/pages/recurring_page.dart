import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../providers/expense_provider.dart';
import '../services/recurring_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../services/money_service.dart';
import '../widgets/app_sheet.dart';
import '../widgets/wallet/recurring_rule_sheet.dart';

/// Repeating transactions: what's coming up, pause, change or stop.
class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  late Future<(List<RecurringRule>, Map<String, Account>)> _rules = _fetch();

  static Future<(List<RecurringRule>, Map<String, Account>)> _fetch() async {
    final (rules, accounts) = await (
      RecurringService().all(),
      AccountService().accounts(includeArchived: true),
    ).wait;
    return (rules, {for (final a in accounts) a.id: a});
  }

  void _reload() => setState(() => _rules = _fetch());

  /// Opens the form for a new rule ([rule] null) or to change one.
  Future<void> _edit([RecurringRule? rule]) async {
    final saved = await showAppSheet<RecurringRule>(
      context: context,
      builder: (_) => RecurringRuleSheet(existing: rule),
    );
    if (saved == null) return;
    await RecurringService().save(saved);
    // Dates up to today are added now (on this device, or by the sync).
    await ref.read(expenseProviderProvider).refreshData();
    _reload();
    if (!mounted) return;
    AppSnackbar.success(
      context,
      rule == null
          ? '${saved.description ?? 'Recurring entry'} saved. '
                'Next on ${DateFormat('d MMM').format(saved.nextDate)}.'
          : 'Changes saved.',
    );
  }

  Future<void> _toggle(RecurringRule rule) async {
    var next = rule.nextDate;
    if (!rule.active) {
      // Resuming skips the dates missed while paused.
      final today = DateUtils.dateOnly(DateTime.now());
      while (next.isBefore(today)) {
        next = advance(next, rule.frequency, rule.anchorDay);
      }
    }
    await RecurringService().save(
      rule.copyWith(active: !rule.active, nextDate: next),
    );
    _reload();
    if (!mounted) return;
    AppSnackbar.info(context, rule.active ? 'Paused.' : 'Resumed.');
  }

  Future<void> _delete(RecurringRule rule) async {
    await RecurringService().delete(rule.id);
    _reload();
    if (!mounted) return;
    AppSnackbar.info(
      context,
      'Stopped repeating. Past entries are kept.',
      actionLabel: 'Undo',
      onAction: () async {
        await RecurringService().save(rule);
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(expenseProviderProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('New recurring'),
      ),
      body: FutureBuilder<(List<RecurringRule>, Map<String, Account>)>(
        future: _rules,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final (rules, accounts) = snap.data!;
          final active = rules.where((r) => r.active);
          final monthly = active.fold<double>(
            0,
            (sum, r) =>
                sum +
                (r.isIncome ? -1 : 1) * r.amount * r.frequency.perYear / 12,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  if (rules.isEmpty)
                    const EmptyState(
                      card: true,
                      icon: Icons.repeat_rounded,
                      title: 'Nothing repeats yet',
                      message:
                          'Add rent, a subscription, an EMI or your salary: '
                          'how much, how often and from when. Each one is '
                          'added for you on the day, with a reminder the '
                          'evening before.',
                    )
                  else ...[
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              monthly >= 0
                                  ? 'Fixed costs a month'
                                  : 'Fixed income a month, after costs',
                              style: AppTextStyles.bodyMd,
                            ),
                          ),
                          Text(
                            formatRupees(monthly.abs()),
                            style: AppTextStyles.h3.copyWith(
                              color: monthly >= 0
                                  ? AppColors.outflow
                                  : AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final r in rules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RuleTile(
                          rule: r,
                          provider: provider,
                          accounts: accounts,
                          onEdit: () => _edit(r),
                          onToggle: () => _toggle(r),
                          onDelete: () => _delete(r),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final RecurringRule rule;
  final ExpenseProvider provider;
  final Map<String, Account> accounts;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.provider,
    required this.accounts,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = provider.categoryOf(rule.expenseOn(rule.nextDate));
    final title = rule.description ?? cat.name;
    return Opacity(
      opacity: rule.active ? 1 : 0.55,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cat.colorValue.withValues(alpha: 0.14),
              child: Icon(cat.iconData, color: cat.colorValue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      rule.frequency.label,
                      if (!rule.active)
                        rule.endDate != null &&
                                rule.nextDate.isAfter(rule.endDate!)
                            ? 'ended'
                            : 'paused'
                      else
                        'next ${DateFormat('d MMM').format(rule.nextDate)}',
                      if (rule.active && rule.endDate != null)
                        'until ${DateFormat('d MMM yy').format(rule.endDate!)}',
                      if (accounts[rule.accountId] != null)
                        accounts[rule.accountId]!.name,
                    ].join(' · '),
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${rule.isIncome ? '+' : ''}${formatRupees(rule.amount)}',
              style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
                color: rule.isIncome ? AppColors.income : AppColors.outflow,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Options for $title',
              onSelected: (v) => switch (v) {
                'edit' => onEdit(),
                'toggle' => onToggle(),
                _ => onDelete(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(rule.active ? 'Pause' : 'Resume'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Stop repeating'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Wallet card: the next few recurring transactions.
class UpcomingRecurringCard extends StatefulWidget {
  final ExpenseProvider provider;
  const UpcomingRecurringCard({super.key, required this.provider});

  @override
  State<UpcomingRecurringCard> createState() => _UpcomingRecurringCardState();
}

class _UpcomingRecurringCardState extends State<UpcomingRecurringCard> {
  late Future<List<RecurringRule>> _rules = RecurringService().all();

  @override
  void didUpdateWidget(UpcomingRecurringCard old) {
    super.didUpdateWidget(old);
    _rules = RecurringService().all();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecurringRule>>(
      future: _rules,
      builder: (context, snap) {
        final rules = (snap.data ?? const []).where((r) => r.active).toList();
        return AppCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/recurring'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.repeat_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Recurring', style: AppTextStyles.h3),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rules.isEmpty)
                    Text(
                      'Rent, subscriptions, salary: add them once and they '
                      'are logged for you.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    for (final r in rules.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(
                                DateFormat('d MMM').format(r.nextDate),
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r.description ??
                                    widget.provider
                                        .categoryOf(r.expenseOn(r.nextDate))
                                        .name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMd,
                              ),
                            ),
                            Text(
                              '${r.isIncome ? '+' : ''}${formatRupees(r.amount)}',
                              style: AppTextStyles.bodyMd.copyWith(
                                fontWeight: FontWeight.w600,
                                color: r.isIncome
                                    ? AppColors.income
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
