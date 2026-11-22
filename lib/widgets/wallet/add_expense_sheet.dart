import 'package:flutter/material.dart';
import '../app_shortcuts.dart';
import '../app_sheet.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/catalog_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/prefs_service.dart';
import '../../models/finance/currency.dart';
import '../../utils/sms_parser.dart';
import '../../services/recurring_service.dart' show Frequency;
import '../animated/animated_segmented_tabs.dart';
import '../animated/fade_slide_in.dart';
import '../animated/tap_scale.dart';
import '../expense_entry_fields.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../../models/expenses.dart';
import '../../utils/format.dart';

/// Bottom-sheet transaction entry: type toggle, Splitwise-style description
/// and amount rows, the category grid, then subcategory / date / payment / trip.
class AddExpenseSheet extends StatefulWidget {
  final Function(Expense) onAdd;

  /// An existing transaction to edit; null to add a new one.
  final Expense? initial;

  /// A bank or UPI message to fill the form from (shared to the app).
  final ParsedSms? prefill;

  /// Offered as "Repeat" when adding: called after [onAdd] with how often
  /// the new transaction recurs.
  final void Function(Expense expense, Frequency frequency)? onRepeat;

  const AddExpenseSheet({
    super.key,
    required this.onAdd,
    this.initial,
    this.onRepeat,
    this.prefill,
  });

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
  Frequency? _repeat;
  String? _error;
  final _cloudinary = CloudinaryService();
  String? _attachmentUrl;
  bool _uploading = false;

  /// The number typed, in [_currency].
  double get _entered => double.tryParse(_amountController.text) ?? 0;

  Currency _currency = homeCurrency;
  final _rateController = TextEditingController();
  double? get _rate => double.tryParse(_rateController.text);

  /// The amount in rupees, which is what gets saved and totalled.
  double get _amount {
    if (_currency.isHome) return _entered;
    final rate = _rate;
    return rate == null || rate <= 0 ? 0 : toHome(_entered, rate);
  }

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
      _attachmentUrl = initial.attachmentUrl;
      if (initial.isForeign) {
        _currency = currencyFor(initial.currency);
        final original = initial.originalAmount!;
        _amountController.text = original == original.roundToDouble()
            ? original.toStringAsFixed(0)
            : original.toStringAsFixed(2);
        _rateController.text = _trimRate(initial.amount / original);
      }
    }
    _rateController.addListener(() => setState(() => _error = null));
    final prefill = widget.prefill;
    if (prefill != null && initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySms(prefill);
      });
    }
    _amountController.addListener(() => setState(() => _error = null));
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _rateController.dispose();
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

  /// Fills the form from a bank or UPI message.
  void _applySms(ParsedSms sms) {
    final amount = sms.amount;
    final category = sms.categoryName == null
        ? null
        : defaultCategories
              .where((c) => c.name == sms.categoryName && c.type == sms.type)
              .firstOrNull;
    setState(() {
      _currency = homeCurrency;
      _amountController.text = amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
      if (sms.merchant != null && _descController.text.trim().isEmpty) {
        _descController.text = sms.merchant!;
      }
      if (sms.paymentMethod != null) _payment = sms.paymentMethod;
      if (sms.date != null) _date = sms.date!;
      if (category != null) _pendingCategoryId = category.id;
    });
    if (sms.type != _type) {
      _setType(sms.type);
    } else if (category != null) {
      _load();
    }
  }

  Future<void> _pasteSms() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final sms = text.isEmpty ? null : parseBankSms(text);
    if (!mounted) return;
    if (sms == null) {
      setState(
        () => _error = text.isEmpty
            ? 'Copy a bank or UPI message first, then tap Paste SMS.'
            : "Couldn't find an amount in the copied text.",
      );
      return;
    }
    _applySms(sms);
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
        title: const Text('New trip'),
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
    if (!_currency.isHome && (_rate == null || _rate! <= 0)) {
      HapticFeedback.mediumImpact();
      setState(
        () => _error =
            'Enter the rate: how many rupees one ${_currency.code} is.',
      );
      return;
    }
    if (amount <= 0) {
      HapticFeedback.mediumImpact();
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (!_currency.isHome) {
      PrefsService().set('rate_${_currency.code}', _rateController.text);
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
    final saved = Expense(
      id: initial?.id,
      attachmentUrl: _attachmentUrl,
      currency: _currency.isHome ? null : _currency.code,
      originalAmount: _currency.isHome ? null : _entered,
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
    );
    widget.onAdd(saved);
    final repeat = _repeat;
    if (repeat != null && !_editing) widget.onRepeat?.call(saved, repeat);
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
  Widget build(BuildContext context) =>
      SaveShortcut(onSave: _save, child: _buildSheet(context));

  Widget _buildSheet(BuildContext context) {
    final isIncome = _type == TxnType.income;
    final accent = isIncome ? AppColors.income : AppColors.outflow;
    final insets = MediaQuery.viewInsetsOf(context);
    // Room left above the keyboard, so the sheet never pushes past the
    // status bar on short phones or in landscape.
    final maxHeight =
        (MediaQuery.sizeOf(context).height -
            insets.bottom -
            MediaQuery.paddingOf(context).top) *
        0.92;
    final amount = _amount;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: GlassContainer(
          borderRadius: 24,
          sheet: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_editing ? 'Edit' : 'Add'} '
                        '${isIncome ? 'income' : 'expense'}',
                        style: AppTextStyles.h3,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 220,
                          child: AnimatedSegmentedTabs(
                            labels: const ['Expense', 'Income'],
                            selectedIndex: _type.index,
                            onChanged: (i) => _setType(TxnType.values[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                          currencySymbol: _currency.symbol,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _currencyRow(),
                      if (!_editing)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _pasteSms,
                            icon: const Icon(Icons.sms_outlined, size: 18),
                            label: const Text('Paste bank SMS'),
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
                      FadeSlideIn(index: 2, child: _details()),
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

  static String _trimRate(double r) {
    final s = r.toStringAsFixed(4);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  Future<void> _selectCurrency(Currency c) async {
    if (c == _currency) return;
    setState(() => _currency = c);
    if (c.isHome) return;
    final saved = await PrefsService().get('rate_${c.code}');
    if (mounted && _currency == c) {
      setState(() => _rateController.text = saved ?? '');
    }
  }

  Future<void> _pickOtherCurrency() async {
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in currencies)
              ListTile(
                leading: SizedBox(
                  width: 44,
                  child: Text(c.symbol.trim(), style: AppTextStyles.h3),
                ),
                title: Text(c.name),
                trailing: Text(c.code),
                selected: c == _currency,
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _selectCurrency(picked);
  }

  /// Rupees by default; a foreign currency asks for the rate and shows the
  /// rupee amount that will be saved.
  Widget _currencyRow() {
    const quick = ['INR', 'USD', 'EUR'];
    final foreign = !_currency.isHome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chipRow([
          for (final code in quick)
            _SelectChip(
              label: code,
              selected: _currency.code == code,
              onTap: () => _selectCurrency(currencyFor(code)),
            ),
          if (!quick.contains(_currency.code))
            _SelectChip(
              label: _currency.code,
              selected: true,
              onTap: _pickOtherCurrency,
            ),
          _SelectChip(
            label: 'Other',
            icon: Icons.language_rounded,
            selected: false,
            onTap: _pickOtherCurrency,
          ),
        ]),
        if (foreign) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text('1 ${_currency.code} = \u20b9', style: AppTextStyles.bodyMd),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'rate',
                  ),
                ),
              ),
              const Spacer(),
              if (_amount > 0)
                Text(
                  '= ${formatRupees(_amount)}',
                  style: AppTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickReceipt({required bool camera}) async {
    final file = await _cloudinary.pickReceiptImage(fromCamera: camera);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await _cloudinary.uploadReceipt(file);
      if (mounted) setState(() => _attachmentUrl = url);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't upload the photo. Try again.");
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _viewReceipt() {
    final url = _attachmentUrl;
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  semanticLabel: 'Receipt photo',
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text("Couldn't load the photo."),
                  ),
                ),
              ),
            ),
            OverflowBar(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _attachmentUrl = null);
                    Navigator.pop(context);
                  },
                  child: const Text('Remove'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Receipt photo row; only when photo upload is set up, or one exists.
  List<Widget> _receipt() {
    if (!_cloudinary.isConfigured && _attachmentUrl == null) return const [];
    final attached = _attachmentUrl != null;
    return [
      const SizedBox(height: 20),
      _section(
        'Receipt',
        _chipRow([
          if (_uploading)
            _SelectChip(
              label: 'Uploading…',
              icon: Icons.cloud_upload_outlined,
              selected: false,
              onTap: () {},
            )
          else if (attached)
            _SelectChip(
              label: 'View photo',
              icon: Icons.receipt_long_rounded,
              selected: true,
              onTap: _viewReceipt,
            )
          else ...[
            _SelectChip(
              label: 'Take photo',
              icon: Icons.photo_camera_outlined,
              selected: false,
              onTap: () => _pickReceipt(camera: true),
            ),
            _SelectChip(
              label: 'From gallery',
              icon: Icons.photo_library_outlined,
              selected: false,
              onTap: () => _pickReceipt(camera: false),
            ),
          ],
        ]),
      ),
    ];
  }

  Widget _details() {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateUtils.dateOnly(_date);
    final otherDay = day != today && day != yesterday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          'Date',
          _chipRow([
            _SelectChip(
              label: 'Today',
              selected: day == today,
              onTap: () => setState(() => _date = today),
            ),
            _SelectChip(
              label: 'Yesterday',
              selected: day == yesterday,
              onTap: () => setState(() => _date = yesterday),
            ),
            _SelectChip(
              label: otherDay ? _dateLabel : 'Pick a date',
              icon: Icons.calendar_today_rounded,
              selected: otherDay,
              onTap: _pickDate,
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _section(
          'Paid with',
          _chipRow([
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
        ..._receipt(),
        if (!_editing && widget.onRepeat != null) ...[
          const SizedBox(height: 20),
          _section(
            'Repeat',
            _chipRow([
              _SelectChip(
                label: 'Never',
                selected: _repeat == null,
                onTap: () => setState(() => _repeat = null),
              ),
              for (final f in Frequency.values)
                _SelectChip(
                  label: f.label,
                  icon: Icons.repeat_rounded,
                  selected: _repeat == f,
                  onTap: () => setState(() => _repeat = f),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        _section(
          'Trip',
          _chipRow([
            for (final e in _events)
              _SelectChip(
                label: e.title,
                selected: _event?.id == e.id,
                onTap: () =>
                    setState(() => _event = _event?.id == e.id ? null : e),
              ),
            _SelectChip(
              label: 'New trip',
              icon: Icons.add_rounded,
              selected: false,
              onTap: _createEvent,
            ),
          ]),
        ),
      ],
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
      Text(title, style: AppTextStyles.fieldLabel),
      const SizedBox(height: 10),
      child,
    ],
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
    // Nothing to drag when the sheet is a dialog.
    if (SheetPresentation.isDialog(context)) return const SizedBox(height: 4);
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
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
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
                width: 42,
                height: 42,
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
