import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/expenses.dart';
import '../../providers/expense_provider.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/format.dart';
import '../app_card.dart';
import '../app_snackbar.dart';
import '../wallet/expense_flows.dart';

/// Log an expense from Home without opening the full form: amount, an
/// optional note, and one of your most-used categories. Enter saves.
/// "More options" opens the full sheet for dates, events and payment method.
class QuickAddCard extends StatefulWidget {
  final ExpenseProvider provider;

  const QuickAddCard({super.key, required this.provider});

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard> {
  static const _shown = 5;

  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  List<Category> _categories = [];
  Category? _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    widget.provider.addListener(_rankCategories);
  }

  @override
  void dispose() {
    widget.provider.removeListener(_rankCategories);
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  List<Category> _all = [];

  Future<void> _loadCategories() async {
    _all = await CatalogService().getCategories(type: TxnType.expense);
    _rankCategories();
  }

  /// Most-used categories this month first, topped up with the defaults.
  void _rankCategories() {
    if (!mounted || _all.isEmpty) return;
    final uses = <String, int>{};
    for (final e in widget.provider.monthExpenses.where((e) => !e.isIncome)) {
      final id = widget.provider.categoryOf(e).id;
      uses[id] = (uses[id] ?? 0) + 1;
    }
    final ranked = [..._all]
      ..sort((a, b) => (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0));
    setState(() {
      _categories = ranked.take(_shown).toList();
      if (_selected == null || !_categories.any((c) => c.id == _selected!.id)) {
        _selected = _categories.first;
      }
    });
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _save() async {
    final category = _selected;
    if (_value <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      _amountFocus.requestFocus();
      return;
    }
    if (category == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final note = _note.text.trim();
    final expense = Expense(
      amount: _value,
      category: category.legacy,
      categoryId: category.id,
      description: note.isEmpty ? null : note,
      timestamp: DateTime.now(),
    );
    await widget.provider.addExpense(expense);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _amount.clear();
    _note.clear();
    setState(() => _saving = false);
    _amountFocus.requestFocus();
    final label = '${formatRupees(expense.amount)} added to ${category.name}.';
    if (widget.provider.monthlySpent > widget.provider.monthlyBudget) {
      AppSnackbar.warning(context, '$label You are over your monthly budget.');
    } else {
      AppSnackbar.success(context, label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Quick add', style: AppTextStyles.h3),
              const Spacer(),
              TextButton(
                onPressed: () => openAddExpense(context, widget.provider),
                child: const Text('More options'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  textInputAction: TextInputAction.next,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0',
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _note,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'What was it for? (optional)',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  avatar: Icon(c.iconData, size: 16, color: c.colorValue),
                  label: Text(c.name),
                  selected: c.id == _selected?.id,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selected = c),
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
