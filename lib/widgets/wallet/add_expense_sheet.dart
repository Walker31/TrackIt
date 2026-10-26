import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/catalog_service.dart';
import '../animated/animated_segmented_tabs.dart';
import '../animated/fade_slide_in.dart';
import '../animated/tap_scale.dart';
import '../expense_entry_fields.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../../models/expenses.dart';
import '../../utils/format.dart';

/// Bottom-sheet transaction entry: amount -> category grid -> optional
/// subcategory / date / payment method / event / note (per the PaisaPulse
/// blueprint).
class AddExpenseSheet extends StatefulWidget {
  final Function(Expense) onAdd;

  /// An existing transaction to edit; null to add a new one.
  final Expense? initial;

  const AddExpenseSheet({super.key, required this.onAdd, this.initial});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  // Smart default: remember the last-used category per type this session.
  static final Map<TxnType, String> _lastCategory = {};
  // Lets the category tile next to the description jump to the grid.
  final _categoryKey = GlobalKey();

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
  DateTime _date = DateTime.now();
  String? _error;

  double get _amount => double.tryParse(_amountController.text) ?? 0;

  bool get _editing => widget.initial != null;

  /// The editing transaction's category, subcategory and event, applied
  /// once the catalog has loaded.
  String? _pendingCategoryId;
  String? _pendingSubcategoryId;
  String? _pendingEventId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _type = initial.type;
      _amountController.text = initial.amount == initial.amount.roundToDouble()
          ? initial.amount.toStringAsFixed(0)
          : initial.amount.toStringAsFixed(2);
      _descController.text = initial.description ?? '';
      _date = initial.timestamp;
      _payment = initial.paymentMethod;
      // Rows from before categories existed map to their default.
      _pendingCategoryId =
          initial.categoryId ??
          defaultCategories
              .where((c) => c.legacy == initial.category && c.type == _type)
              .firstOrNull
              ?.id;
      _pendingSubcategoryId = initial.subcategoryId;
      _pendingEventId = initial.eventId;
    }
    _amountController.addListener(() => setState(() => _error = null));
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
    final wantedId = _pendingCategoryId ?? _lastCategory[_type];
    _pendingCategoryId = null;
    final selected =
        categories.where((c) => c.id == wantedId).firstOrNull ??
        categories.firstOrNull;
    final eventId = _pendingEventId ?? _event?.id;
    _pendingEventId = null;
    setState(() {
      _categories = categories;
      _events = events;
      _event = _events.where((e) => e.id == eventId).firstOrNull;
    });
    if (selected != null) await _selectCategory(selected);
    final subId = _pendingSubcategoryId;
    _pendingSubcategoryId = null;
    if (subId != null && mounted) {
      setState(
        () => _subcategory = _subcategories
            .where((s) => s.id == subId)
            .firstOrNull,
      );
    }
  }

  Future<void> _selectCategory(Category c) async {
    HapticFeedback.selectionClick();
    final subs = await _catalog.getSubcategories(c.id);
    if (!mounted) return;
    setState(() {
      _category = c;
      _subcategories = subs;
      _subcategory = null;
      _error = null;
    });
  }

  void _setType(TxnType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _category = null;
      _subcategories = [];
    });
    _load();
  }

  void _jumpToCategories() {
    final target = _categoryKey.currentContext;
    if (target == null) return;
    HapticFeedback.selectionClick();
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
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
    final amount = _amount;
    final category = _category;
    if (amount <= 0) {
      HapticFeedback.mediumImpact();
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (category == null) {
      HapticFeedback.mediumImpact();
      setState(() => _error = 'Pick a category to continue.');
      return;
    }
    _lastCategory[_type] = category.id;
    final now = DateTime.now();
    final initial = widget.initial;
    // An edit that keeps the day keeps the original time of day.
    final keepTime =
        initial != null && DateUtils.isSameDay(initial.timestamp, _date);
    widget.onAdd(
      Expense(
        id: initial?.id,
        attachmentUrl: initial?.attachmentUrl,
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
        // Keep the current time of day so same-day entries stay ordered.
        timestamp: keepTime
            ? initial.timestamp
            : DateTime(
                _date.year,
                _date.month,
                _date.day,
                now.hour,
                now.minute,
                now.second,
              ),
      ),
    );
    Navigator.pop(context);
  }

  String get _dateLabel {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(_date);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(_date);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == TxnType.income;
    final accent = isIncome ? AppColors.income : AppColors.expense;
    final media = MediaQuery.of(context);
    final amount = _amount;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: GlassContainer(
          borderRadius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: _fadeSlide,
                        layoutBuilder: _alignStart,
                        child: Text(
                          '${_editing ? 'Edit' : 'Add'} '
                          '${isIncome ? 'income' : 'expense'}',
                          key: ValueKey(_type),
                          style: AppTextStyles.h2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: AnimatedSegmentedTabs(
                  labels: const ['Expense', 'Income'],
                  selectedIndex: _type.index,
                  onChanged: (i) => _setType(TxnType.values[i]),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        child: ExpenseEntryFields(
                          descriptionController: _descController,
                          amountController: _amountController,
                          icon:
                              _category?.iconData ??
                              Icons.receipt_long_outlined,
                          iconColor:
                              _category?.colorValue ?? AppColors.textSecondary,
                          accent: accent,
                          onIconTap: _jumpToCategories,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeSlideIn(
                        key: _categoryKey,
                        index: 1,
                        child: _section('Category', _categoryGrid()),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _subcategories.isEmpty
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: _section(
                                  'Subcategory',
                                  _chipRow([
                                    for (final s in _subcategories)
                                      _SelectChip(
                                        label: s.name,
                                        selected: _subcategory?.id == s.id,
                                        color: _category?.colorValue,
                                        onTap: () => setState(
                                          () => _subcategory =
                                              _subcategory?.id == s.id
                                              ? null
                                              : s,
                                        ),
                                      ),
                                  ]),
                                ),
                              ),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(index: 2, child: _detailsCard()),
                    ],
                  ),
                ),
              ),
              _footer(accent, amount, isIncome),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    if (_categories.isEmpty) {
      return const SizedBox(
        height: 88,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: _fadeSlide,
          layoutBuilder: _alignStart,
          child: Wrap(
            key: ValueKey(_type),
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < _categories.length; i++)
                FadeSlideIn(
                  index: i,
                  baseDelay: const Duration(milliseconds: 18),
                  child: SizedBox(
                    width: width,
                    child: _CategoryTile(
                      category: _categories[i],
                      selected: _categories[i].id == _category?.id,
                      onTap: () => _selectCategory(_categories[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailsCard() {
    return _section(
      'Details',
      Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              trailing: TapScale(
                onTap: _pickDate,
                child: _Pill(text: _dateLabel, icon: Icons.expand_more_rounded),
              ),
            ),
            _divider(),
            _DetailRow(
              icon: Icons.payments_outlined,
              label: 'Paid with',
              child: _chipRow([
                for (final p in PaymentMethod.values)
                  _SelectChip(
                    label: p.label,
                    icon: p.icon,
                    selected: _payment == p,
                    onTap: () =>
                        setState(() => _payment = _payment == p ? null : p),
                  ),
              ]),
            ),
            _divider(),
            _DetailRow(
              icon: Icons.luggage_outlined,
              label: 'Event',
              child: _chipRow([
                _SelectChip(
                  label: 'New',
                  icon: Icons.add_rounded,
                  selected: false,
                  onTap: _createEvent,
                ),
                for (final e in _events)
                  _SelectChip(
                    label: e.title,
                    selected: _event?.id == e.id,
                    onTap: () =>
                        setState(() => _event = _event?.id == e.id ? null : e),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(Color accent, double amount, bool isIncome) {
    final kind = isIncome ? 'income' : 'expense';
    final label = _editing
        ? 'Save changes'
        : amount > 0
        ? 'Save ${formatRupees(amount)} $kind'
        : 'Save $kind';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textTertiary.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: AppColors.expense,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          AppButton(text: label, color: accent, onPressed: _save),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTextStyles.label),
      const SizedBox(height: 10),
      child,
    ],
  );

  Widget _divider() => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: AppColors.textTertiary.withValues(alpha: 0.15),
  );

  Widget _chipRow(List<Widget> chips) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => chips[i],
    ),
  );

  static Widget _fadeSlide(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );

  static Widget _alignStart(Widget? current, List<Widget> previous) =>
      Stack(alignment: Alignment.topLeft, children: [...previous, ?current]);
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Widget? child;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Pill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              text,
              key: ValueKey(text),
              style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(icon, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Pill chip that animates its fill and border when toggled.
class _SelectChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final fg = selected ? accent : AppColors.textPrimary;
    return TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : AppColors.textTertiary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

  /// Wraps at spaces only: a single long word ("Entertainment") shrinks to
  /// fit on one line instead of breaking mid-word on narrow phones.
  Widget _label(Color color) {
    final style = AppTextStyles.label.copyWith(
      fontSize: 10.5,
      height: 1.25,
      letterSpacing: 0.1,
      color: selected ? color : AppColors.textSecondary,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    if (!category.name.contains(' ')) {
      return Align(
        alignment: Alignment.topCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(category.name, maxLines: 1, style: style),
        ),
      );
    }
    return Text(
      category.name,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = category.colorValue;
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.7) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category.iconData,
                  color: selected ? Colors.white : color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Fixed two-line slot keeps every tile in a row the same height.
            SizedBox(height: 28, child: _label(color)),
          ],
        ),
      ),
    );
  }
}
