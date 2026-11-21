import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expenses.dart';
import '../providers/app_providers.dart';
import '../providers/expense_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/format.dart';
import '../utils/transaction_filter.dart';
import '../widgets/app_card.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/wallet/add_expense_sheet.dart';
import '../widgets/wallet/transaction_list.dart';

/// Search every transaction by text, type, category, payment method, date
/// and amount.
class TransactionsPage extends ConsumerStatefulWidget {
  /// Filters to open with (e.g. from a tapped chart bar).
  final TransactionFilter initial;

  const TransactionsPage({super.key, this.initial = const TransactionFilter()});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _search = TextEditingController();
  late TransactionFilter _filter = widget.initial;
  List<Expense>? _all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await ref.read(expenseProviderProvider).allExpenses();
    if (mounted) setState(() => _all = all);
  }

  Future<void> _openFilters(ExpenseProvider provider) async {
    final result = await showAppSheet<TransactionFilter>(
      context: context,
      builder: (_) =>
          _FilterSheet(initial: _filter, categories: provider.categories),
    );
    if (result != null) setState(() => _filter = result);
  }

  void _edit(Expense expense) {
    final provider = ref.read(expenseProviderProvider);
    showAppSheet(
      context: context,
      builder: (_) => AddExpenseSheet(
        initial: expense,
        onAdd: (updated) async {
          await provider.updateExpense(updated);
          if (!mounted) return;
          AppSnackbar.success(
            context,
            '${updated.isIncome ? 'Income' : 'Expense'} updated.',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(expenseProviderProvider);
    ref.listen(expenseProviderProvider, (_, _) => _load());
    final all = _all;
    final results = all == null
        ? const <Expense>[]
        : [
            for (final e in all)
              if (_filter.matches(e, provider.categoryOf(e))) e,
          ];
    final totals = totalsOf(results);
    final filters = _filter.activeCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Search transactions')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      autofocus: widget.initial.isEmpty,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) =>
                          setState(() => _filter = _filter.copyWith(query: v)),
                      decoration: InputDecoration(
                        hintText: 'Note, category or amount',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _filter = _filter.copyWith(query: '');
                                }),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: filters > 0,
                    label: Text('$filters'),
                    child: IconButton.filledTonal(
                      tooltip: filters == 0
                          ? 'Filters'
                          : 'Filters ($filters active)',
                      onPressed: () => _openFilters(provider),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _QuickFilters(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              if (all != null && results.isNotEmpty)
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${totals.count} '
                          '${totals.count == 1 ? 'transaction' : 'transactions'}',
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (totals.spent > 0)
                        Text(
                          '−${formatRupees(totals.spent)}',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.outflow,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (totals.spent > 0 && totals.received > 0)
                        const SizedBox(width: 12),
                      if (totals.received > 0)
                        Text(
                          '+${formatRupees(totals.received)}',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.income,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (all == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TransactionList(
                  provider: provider,
                  items: results,
                  onEdit: _edit,
                  empty: EmptyState(
                    card: true,
                    icon: Icons.search_off_rounded,
                    title: all.isEmpty
                        ? 'No transactions yet'
                        : 'Nothing matches',
                    message: all.isEmpty
                        ? 'Add an expense from the Wallet tab.'
                        : 'Try fewer words or clear a filter.',
                    actionLabel: _filter.isEmpty ? null : 'Clear all',
                    onAction: _filter.isEmpty
                        ? null
                        : () => setState(() {
                            _search.clear();
                            _filter = const TransactionFilter();
                          }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-tap filters: type and common date ranges.
class _QuickFilters extends StatelessWidget {
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onChanged;

  const _QuickFilters({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ranges = <String, (DateTime, DateTime)>{
      'Last 7 days': (today.subtract(const Duration(days: 6)), today),
      'This month': (DateTime(now.year, now.month), today),
      'Last month': (
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month, 0),
      ),
      'This year': (DateTime(now.year), today),
    };
    bool rangeIs((DateTime, DateTime) r) =>
        filter.from == r.$1 && filter.to == r.$2;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in TxnType.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(t == TxnType.income ? 'Income' : 'Expenses'),
                selected: filter.type == t,
                onSelected: (on) =>
                    onChanged(filter.copyWith(type: () => on ? t : null)),
              ),
            ),
          const SizedBox(width: 6),
          for (final entry in ranges.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(entry.key),
                selected: rangeIs(entry.value),
                onSelected: (on) => onChanged(
                  filter.copyWith(
                    from: () => on ? entry.value.$1 : null,
                    to: () => on ? entry.value.$2 : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  final List<Category> categories;

  const _FilterSheet({required this.initial, required this.categories});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _f = widget.initial;
  late final _min = TextEditingController(
    text: widget.initial.minAmount?.toStringAsFixed(0) ?? '',
  );
  late final _max = TextEditingController(
    text: widget.initial.maxAmount?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _f.from != null && _f.to != null
          ? DateTimeRange(start: _f.from!, end: _f.to!)
          : null,
    );
    if (range != null) {
      setState(
        () => _f = _f.copyWith(from: () => range.start, to: () => range.end),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final cats = widget.categories
        .where((c) => _f.type == null || c.type == _f.type)
        .toList();
    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 24,
      sheet: true,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Filters', style: AppTextStyles.h2)),
                TextButton(
                  onPressed: () => setState(() {
                    _min.clear();
                    _max.clear();
                    _f = TransactionFilter(query: _f.query);
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Date', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text(
                _f.from == null
                    ? 'Any date'
                    : '${fmt.format(_f.from!)} – ${fmt.format(_f.to ?? _f.from!)}',
              ),
            ),
            const SizedBox(height: 16),
            Text('Amount (₹)', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(hintText: 'Min'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(hintText: 'Max'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Category', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in cats)
                  FilterChip(
                    avatar: Icon(c.iconData, size: 16, color: c.colorValue),
                    label: Text(c.name),
                    selected: _f.categoryIds.contains(c.id),
                    onSelected: (on) => setState(() {
                      final ids = {..._f.categoryIds};
                      on ? ids.add(c.id) : ids.remove(c.id);
                      _f = _f.copyWith(categoryIds: ids);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Paid with', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in PaymentMethod.values)
                  FilterChip(
                    avatar: Icon(p.icon, size: 16),
                    label: Text(p.label),
                    selected: _f.paymentMethods.contains(p),
                    onSelected: (on) => setState(() {
                      final set = {..._f.paymentMethods};
                      on ? set.add(p) : set.remove(p);
                      _f = _f.copyWith(paymentMethods: set);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final min = double.tryParse(_min.text);
                  final max = double.tryParse(_max.text);
                  Navigator.pop(
                    context,
                    _f.copyWith(minAmount: () => min, maxAmount: () => max),
                  );
                },
                child: const Text('Show results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
