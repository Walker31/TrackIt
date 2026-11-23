import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/expenses.dart';
import '../../services/catalog_service.dart';
import '../../services/money_service.dart';
import '../../services/recurring_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/format.dart';
import '../app_button.dart';
import '../glass_container.dart';

enum _Ends { never, onDate, afterCount }

/// Create or change a recurring transaction: what, how much, which account,
/// how often, from when, and until when. Returns the rule to save.
class RecurringRuleSheet extends StatefulWidget {
  final RecurringRule? existing;
  const RecurringRuleSheet({super.key, this.existing});

  @override
  State<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends State<RecurringRuleSheet> {
  late final RecurringRule? _e = widget.existing;
  late TxnType _type = _e?.type ?? TxnType.expense;
  late final _note = TextEditingController(text: _e?.description ?? '');
  late final _amount = TextEditingController(
    text: _e == null ? '' : _plain(_e.amount),
  );
  final _count = TextEditingController(text: '12');
  late Frequency _frequency = _e?.frequency ?? Frequency.monthly;
  late DateTime _date = _e?.nextDate ?? _defaultFirst();
  late _Ends _ends = _e?.endDate == null ? _Ends.never : _Ends.onDate;
  late DateTime? _endDate = _e?.endDate;
  late String? _categoryId = _e?.categoryId;
  late String? _accountId = _e?.accountId;
  late PaymentMethod? _payment = _e?.paymentMethod;

  List<Category> _categories = const [];
  List<Account> _accounts = const [];
  String? _error;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// The 1st of next month: the usual start for rent or a subscription.
  static DateTime _defaultFirst() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final categories = await CatalogService().getCategories(type: _type);
    final accounts = await AccountService().accounts();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _accounts = accounts;
      if (!categories.any((c) => c.id == _categoryId)) {
        // Rules from before categories carry only the legacy bucket.
        _categoryId =
            categories
                .where((c) => _e != null && c.legacy == _e.category)
                .firstOrNull
                ?.id ??
            categories.firstOrNull?.id;
      }
    });
  }

  Future<void> _pickDate({required bool end}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: end ? _date : DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
      initialDate: end ? (_endDate ?? nthDate(_date, _frequency, 12)) : _date,
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _endDate = picked;
      } else {
        _date = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      }
    });
  }

  /// The end date the choice means, or null for "never".
  DateTime? get _resolvedEnd => switch (_ends) {
    _Ends.never => null,
    _Ends.onDate => _endDate,
    _Ends.afterCount => () {
      final n = int.tryParse(_count.text);
      return n == null || n < 1 ? null : nthDate(_date, _frequency, n);
    }(),
  };

  void _save() {
    final amount = double.tryParse(_amount.text);
    final category = _categories.where((c) => c.id == _categoryId).firstOrNull;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (category == null) {
      setState(() => _error = 'Pick a category.');
      return;
    }
    if (_ends == _Ends.onDate && _endDate == null) {
      setState(() => _error = 'Pick the last date, or choose Never.');
      return;
    }
    if (_ends == _Ends.afterCount && (int.tryParse(_count.text) ?? 0) < 1) {
      setState(() => _error = 'Enter how many times it happens.');
      return;
    }
    final note = _note.text.trim();
    final end = _resolvedEnd;
    final account = _accounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;
    final e = _e;
    final rule = e == null
        ? RecurringRule.starting(
            first: _date,
            frequency: _frequency,
            amount: amount,
            type: _type,
            category: category.legacy,
            categoryId: category.id,
            paymentMethod: _payment,
            description: note.isEmpty ? null : note,
            endDate: end,
            accountId: account,
          )
        : e.copyWith(
            amount: amount,
            type: _type,
            category: category.legacy,
            categoryId: () => category.id,
            subcategoryId: () =>
                category.id == e.categoryId ? e.subcategoryId : null,
            paymentMethod: () => _payment,
            description: () => note.isEmpty ? null : note,
            frequency: _frequency,
            nextDate: _date,
            endDate: () => end,
            accountId: () => account,
          );
    Navigator.pop(context, rule);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final preview = RecurringRule.starting(
      first: _date,
      frequency: _frequency,
      amount: 1,
      type: _type,
      category: ExpenseCategory.other,
      endDate: _resolvedEnd,
    ).upcoming(3);
    final fmt = DateFormat('d MMM yyyy');
    return GlassContainer(
      sheet: true,
      borderRadius: 24,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        top: 20,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _e == null ? 'New recurring' : 'Edit recurring',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 16),
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(value: TxnType.expense, label: Text('Expense')),
                ButtonSegment(value: TxnType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'What is it?',
                hintText: _type == TxnType.income
                    ? 'e.g. Salary'
                    : 'e.g. Rent, Netflix, Gym',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
            _label('Category'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    avatar: Icon(c.iconData, size: 16, color: c.colorValue),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            if (_accounts.isNotEmpty) ...[
              _label(_type == TxnType.income ? 'Into account' : 'From account'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in _accounts)
                    ChoiceChip(
                      avatar: Icon(a.kind.icon, size: 16),
                      label: Text(a.name),
                      selected: _accountId == a.id,
                      showCheckmark: false,
                      onSelected: (on) =>
                          setState(() => _accountId = on ? a.id : null),
                    ),
                ],
              ),
            ],
            _label('Paid with'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in PaymentMethod.values)
                  ChoiceChip(
                    avatar: Icon(p.icon, size: 16),
                    label: Text(p.label),
                    selected: _payment == p,
                    showCheckmark: false,
                    onSelected: (on) =>
                        setState(() => _payment = on ? p : null),
                  ),
              ],
            ),
            _label('How often'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in Frequency.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _frequency == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
              ],
            ),
            _label(_e == null ? 'First one on' : 'Next one on'),
            OutlinedButton.icon(
              onPressed: () => _pickDate(end: false),
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(fmt.format(_date)),
            ),
            if (_e == null && !_date.isAfter(today))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Dates up to today are added straight away.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            _label('Ends'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Never'),
                  selected: _ends == _Ends.never,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _ends = _Ends.never),
                ),
                ChoiceChip(
                  label: const Text('On a date'),
                  selected: _ends == _Ends.onDate,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _ends = _Ends.onDate),
                ),
                ChoiceChip(
                  label: const Text('After a number of times'),
                  selected: _ends == _Ends.afterCount,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _ends = _Ends.afterCount),
                ),
              ],
            ),
            if (_ends == _Ends.onDate)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(end: true),
                  icon: const Icon(Icons.event_busy_rounded, size: 18),
                  label: Text(
                    _endDate == null
                        ? 'Pick the last date'
                        : 'Last one on or before ${fmt.format(_endDate!)}',
                  ),
                ),
              ),
            if (_ends == _Ends.afterCount)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _count,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resolvedEnd == null
                            ? 'times'
                            : 'times, last on ${fmt.format(_resolvedEnd!)}',
                        style: AppTextStyles.bodyMd,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              preview.isEmpty
                  ? 'Nothing left to add before it ends.'
                  : 'Next: ${preview.map(DateFormat('d MMM').format).join(', ')}'
                        '${preview.length == 3 ? '…' : ''}',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (_e != null)
              Text(
                'Changes apply from the next one. Entries already added stay '
                'as they are.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              text: _e == null
                  ? 'Save recurring'
                  : (double.tryParse(_amount.text) != null
                        ? 'Save ${formatRupees(double.parse(_amount.text))}'
                        : 'Save'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text, style: AppTextStyles.fieldLabel),
  );
}
