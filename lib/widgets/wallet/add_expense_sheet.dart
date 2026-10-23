import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/catalog_service.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../../models/expenses.dart';

/// Bottom-sheet transaction entry: amount -> category grid -> optional
/// subcategory / event / payment method (per the PaisaPulse blueprint).
class AddExpenseSheet extends StatefulWidget {
  final Function(Expense) onAdd;
  const AddExpenseSheet({super.key, required this.onAdd});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  // Smart default: remember the last-used category per type this session.
  static final Map<TxnType, String> _lastCategory = {};

  final _catalog = CatalogService();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  TxnType _type = TxnType.expense;
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  List<SpendEvent> _events = [];
  Category? _category;
  Subcategory? _subcategory;
  SpendEvent? _event;
  PaymentMethod? _payment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final categories = await _catalog.getCategories(type: _type);
    final events = await _catalog.getEvents();
    if (!mounted) return;
    final lastId = _lastCategory[_type];
    final selected =
        categories.where((c) => c.id == lastId).firstOrNull ??
        categories.firstOrNull;
    setState(() {
      _categories = categories;
      _events = events;
      _event = _events.where((e) => e.id == _event?.id).firstOrNull;
    });
    if (selected != null) await _selectCategory(selected);
  }

  Future<void> _selectCategory(Category c) async {
    final subs = await _catalog.getSubcategories(c.id);
    if (!mounted) return;
    setState(() {
      _category = c;
      _subcategories = subs;
      _subcategory = null;
    });
  }

  Future<void> _createEvent() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New event'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Goa trip'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    final event = await _catalog.addEvent(title: title);
    if (!mounted) return;
    setState(() {
      _events = [event, ..._events];
      _event = event;
    });
  }

  void _save() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final category = _category;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (category == null) {
      setState(() => _error = 'Pick a category to continue.');
      return;
    }
    _lastCategory[_type] = category.id;
    widget.onAdd(
      Expense(
        amount: amount,
        type: _type,
        category: category.legacy,
        categoryId: category.id,
        subcategoryId: _subcategory?.id,
        eventId: _event?.id,
        paymentMethod: _payment,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        timestamp: DateTime.now(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _type == TxnType.income
        ? AppColors.income
        : AppColors.expense;

    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 32,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _type == TxnType.income ? 'Add Income' : 'Add Expense',
                  style: AppTextStyles.h2,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(value: TxnType.expense, label: Text('Expense')),
                ButtonSegment(value: TxnType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() {
                  _type = s.first;
                  _category = null;
                  _subcategories = [];
                });
                _load();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTextStyles.h1.copyWith(color: accent),
              decoration: const InputDecoration(
                prefixText: '₹',
                hintText: '0.00',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            Text('Category', style: AppTextStyles.label),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in _categories)
                  _CategoryTile(
                    category: c,
                    selected: c.id == _category?.id,
                    onTap: () => _selectCategory(c),
                  ),
              ],
            ),
            if (_subcategories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Subcategory', style: AppTextStyles.label),
              const SizedBox(height: 8),
              _chipRow([
                for (final s in _subcategories)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(s.name),
                    selected: _subcategory?.id == s.id,
                    onSelected: (v) =>
                        setState(() => _subcategory = v ? s : null),
                  ),
              ]),
            ],
            const SizedBox(height: 20),
            Text('Event (optional)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            _chipRow([
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                onPressed: _createEvent,
              ),
              for (final e in _events)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(e.title),
                  selected: _event?.id == e.id,
                  onSelected: (v) => setState(() => _event = v ? e : null),
                ),
            ]),
            const SizedBox(height: 20),
            Text('Paid with (optional)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            _chipRow([
              for (final p in PaymentMethod.values)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(p.icon, size: 16),
                  label: Text(p.label),
                  selected: _payment == p,
                  onSelected: (v) => setState(() => _payment = v ? p : null),
                ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(hintText: 'Note (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              text: _type == TxnType.income ? 'Save Income' : 'Save Expense',
              color: accent,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => chips[i],
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.colorValue;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.25 : 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(category.iconData, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
