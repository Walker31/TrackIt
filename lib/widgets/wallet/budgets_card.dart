import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/expenses.dart';
import '../../providers/expense_provider.dart';
import '../../services/budget_alert_service.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../confirm_dialog.dart';
import '../glass_container.dart';
import '../../utils/format.dart';

class _BudgetRow {
  final Budget budget;
  final Category category;
  final double spent;
  const _BudgetRow(this.budget, this.category, this.spent);
}

/// Per-category monthly budgets (blueprint `budgets` table) with progress.
class BudgetsCard extends StatefulWidget {
  final ExpenseProvider provider;
  const BudgetsCard({super.key, required this.provider});

  @override
  State<BudgetsCard> createState() => _BudgetsCardState();
}

class _BudgetsCardState extends State<BudgetsCard> {
  final _catalog = CatalogService();
  late Future<List<_BudgetRow>> _future = _load();

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_reload);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<List<_BudgetRow>> _load() async {
    final month = widget.provider.selectedMonth;
    final categories = {
      for (final c in await _catalog.getCategories()) c.id: c,
    };
    final spent = await _catalog.getMonthlySpendByCategory(month);
    return [
      for (final b in await _catalog.getBudgetsForMonth(month))
        if (categories[b.categoryId] != null)
          _BudgetRow(b, categories[b.categoryId]!, spent[b.categoryId] ?? 0),
    ];
  }

  Future<void> _editBudget({Category? preset, double? current}) async {
    final categories = preset != null
        ? [preset]
        : await _catalog.getCategories(type: TxnType.expense);
    if (!mounted) return;
    var selected = preset ?? categories.first;
    final amount = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(preset == null ? 'Set category budget' : preset.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preset == null)
                DropdownButton<Category>(
                  isExpanded: true,
                  value: selected,
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (c) => setState(() => selected = c ?? selected),
                ),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  prefixText: '₹',
                  hintText: 'Monthly limit',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final value = double.tryParse(amount.text);
    amount.dispose();
    if (ok != true || value == null || value <= 0) return;
    await _catalog.setBudget(selected.id, widget.provider.selectedMonth, value);
    _reload();
    // A limit set below what's already spent warns straight away.
    unawaited(BudgetAlertService().check());
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: FutureBuilder<List<_BudgetRow>>(
        future: _future,
        builder: (context, snap) {
          final rows = snap.data ?? const <_BudgetRow>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Category budgets',
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _editBudget,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (rows.isEmpty)
                Text(
                  'Set a monthly limit for a category to track it here.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              for (final r in rows) _row(r),
            ],
          );
        },
      ),
    );
  }

  Widget _row(_BudgetRow r) {
    final ratio = r.spent / r.budget.limitAmount;
    final over = ratio > 1;
    final color = over ? AppColors.outflow : r.category.colorValue;
    return InkWell(
      onTap: () =>
          _editBudget(preset: r.category, current: r.budget.limitAmount),
      onLongPress: () async {
        final confirmed = await confirmDestructive(
          context,
          title: 'Remove budget?',
          message:
              'The ${formatRupees(r.budget.limitAmount)} limit for '
              '${r.category.name} will be removed for this month.',
          action: 'Remove',
        );
        if (!confirmed) return;
        await _catalog.deleteBudget(r.budget.id);
        _reload();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(r.category.iconData, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.category.name, style: AppTextStyles.bodyMd),
                ),
                Text(
                  '${formatRupees(r.spent)} / '
                  '${formatRupees(r.budget.limitAmount)}',
                  style: AppTextStyles.bodySm.copyWith(
                    color: over ? AppColors.outflow : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
