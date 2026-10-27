import '../expense_entry_fields.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../../services/cloudinary_service.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../member_avatar.dart';
import '../../utils/format.dart';

class AddGroupExpenseSheet extends StatefulWidget {
  final Group group;
  final int? defaultPayerMemberId;
  final Future<void> Function(GroupExpense expense) onAdd;

  /// An existing expense to edit; null to add a new one.
  final GroupExpense? initial;

  const AddGroupExpenseSheet({
    super.key,
    required this.group,
    required this.onAdd,
    this.defaultPayerMemberId,
    this.initial,
  });

  @override
  State<AddGroupExpenseSheet> createState() => _AddGroupExpenseSheetState();
}

class _AddGroupExpenseSheetState extends State<AddGroupExpenseSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final CloudinaryService _cloudinary = CloudinaryService();

  ExpenseCategory _category = ExpenseCategory.food;
  SplitType _splitType = SplitType.equal;
  late int _payerMemberId;
  late Set<int> _includedMemberIds;
  final Map<int, TextEditingController> _shareControllers = {};

  String? _receiptUrl;
  bool _isUploadingReceipt = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _payerMemberId =
        widget.defaultPayerMemberId ?? widget.group.members.first.id!;
    _includedMemberIds = widget.group.members.map((m) => m.id!).toSet();
    for (final m in widget.group.members) {
      _shareControllers[m.id!] = TextEditingController();
    }

    final initial = widget.initial;
    if (initial != null) {
      _amountController.text = _trim(initial.amount);
      _descController.text = initial.description ?? '';
      _category = initial.category;
      _splitType = initial.splitType;
      _receiptUrl = initial.receiptUrl;
      if (_includedMemberIds.contains(initial.payerMemberId)) {
        _payerMemberId = initial.payerMemberId;
      }
      _includedMemberIds = {
        for (final s in initial.splits)
          if (_shareControllers.containsKey(s.memberId)) s.memberId,
      };
      for (final s in initial.splits) {
        _shareControllers[s.memberId]?.text = switch (_splitType) {
          SplitType.percentage when initial.amount > 0 => _trim(
            s.shareAmount / initial.amount * 100,
          ),
          _ => _trim(s.shareAmount),
        };
      }
    }
  }

  /// 120.0 -> "120", 33.333 -> "33.33".
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0.0;

  List<ExpenseSplit> _computeSplits() {
    final included = widget.group.members
        .where((m) => _includedMemberIds.contains(m.id))
        .toList();
    if (included.isEmpty) return [];

    switch (_splitType) {
      case SplitType.equal:
        final share = _amount / included.length;
        return included
            .map(
              (m) => ExpenseSplit(
                expenseId: 0,
                memberId: m.id!,
                shareAmount: share,
              ),
            )
            .toList();
      case SplitType.exact:
        return included
            .map(
              (m) => ExpenseSplit(
                expenseId: 0,
                memberId: m.id!,
                shareAmount:
                    double.tryParse(_shareControllers[m.id]?.text ?? '') ?? 0.0,
              ),
            )
            .toList();
      case SplitType.percentage:
        return included
            .map(
              (m) => ExpenseSplit(
                expenseId: 0,
                memberId: m.id!,
                shareAmount:
                    _amount *
                    (double.tryParse(_shareControllers[m.id]?.text ?? '') ??
                        0.0) /
                    100,
              ),
            )
            .toList();
    }
  }

  Future<void> _pickReceipt() async {
    if (!_cloudinary.isConfigured) {
      setState(() => _error = 'Receipt upload is not configured yet.');
      return;
    }
    final file = await _cloudinary.pickReceiptImage();
    if (file == null) return;

    setState(() => _isUploadingReceipt = true);
    try {
      final url = await _cloudinary.uploadReceipt(file);
      setState(() {
        _receiptUrl = url;
        _isUploadingReceipt = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingReceipt = false;
        _error = 'Failed to upload receipt.';
      });
    }
  }

  Future<void> _save() async {
    final splits = _computeSplits();
    if (_amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    if (splits.isEmpty) {
      setState(() => _error = 'Split it with at least one person.');
      return;
    }

    if (_splitType != SplitType.equal) {
      final total = splits.fold<double>(0, (sum, s) => sum + s.shareAmount);
      if ((total - _amount).abs() > 0.5) {
        setState(
          () => _error = _splitType == SplitType.percentage
              ? 'Percentages must add up to 100%. Tap the split to fix.'
              : 'Amounts must add up to the total. Tap the split to fix.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    await widget.onAdd(
      GroupExpense(
        id: widget.initial?.id,
        remoteId: widget.initial?.remoteId,
        groupId: widget.group.id!,
        payerMemberId: _payerMemberId,
        amount: _amount,
        category: _category,
        description: _descController.text.isEmpty ? null : _descController.text,
        timestamp: widget.initial?.timestamp ?? DateTime.now(),
        receiptUrl: _receiptUrl,
        splitType: _splitType,
        splits: splits,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  /// The viewer's member id, for "you" in labels.
  int? get _me => widget.defaultPayerMemberId;

  String _nameOf(GroupMember m) => m.id == _me ? 'You' : m.username;

  GroupMember? _member(int id) =>
      widget.group.members.where((m) => m.id == id).firstOrNull;

  String get _payerLabel {
    if (_payerMemberId == _me) return 'you';
    return _member(_payerMemberId)?.username ?? 'someone';
  }

  String get _splitLabel {
    final everyone = _includedMemberIds.length == widget.group.members.length;
    return switch (_splitType) {
      SplitType.equal when everyone => 'equally',
      SplitType.equal => 'equally between ${_includedMemberIds.length}',
      SplitType.exact => 'by exact amounts',
      SplitType.percentage => 'by percentages',
    };
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: GlassContainer(
          borderRadius: 24,
          sheet: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initial == null ? 'Add expense' : 'Edit expense',
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _withLine(),
                      const SizedBox(height: 20),
                      ExpenseEntryFields(
                        descriptionController: _descController,
                        amountController: _amountController,
                        icon: _category.icon,
                        iconColor: _category.color,
                        accent: AppColors.outflow,
                        onAmountChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 20),
                      _paidBySplitLine(),
                      const SizedBox(height: 24),
                      Text('Category', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 10),
                      _categoryRow(),
                      const SizedBox(height: 20),
                      _receiptRow(),
                    ],
                  ),
                ),
              ),
              Container(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.expense,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    AppButton(
                      text: widget.initial == null
                          ? 'Save expense'
                          : 'Save changes',
                      isLoading: _isSaving,
                      color: AppColors.outflow,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "With you and: Asha, Ravi" — who the expense is shared with.
  Widget _withLine() {
    final others = [
      for (final m in widget.group.members)
        if (m.id != _me && _includedMemberIds.contains(m.id)) m,
    ];
    return Row(
      children: [
        Text(
          others.isEmpty ? 'Just you' : 'With you and:',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: others.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MemberAvatar(name: others[i].username, size: 24),
                    const SizedBox(width: 6),
                    Text(
                      others[i].username,
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Paid by [you] and split [equally]" — each pill opens its options.
  Widget _paidBySplitLine() {
    final base = AppTextStyles.bodyLg.copyWith(color: AppColors.textPrimary);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          Text('Paid by', style: base),
          _OptionPill(label: _payerLabel, onTap: _choosePayer),
          Text('and split', style: base),
          _OptionPill(label: _splitLabel, onTap: _chooseSplit),
        ],
      ),
    );
  }

  Widget _categoryRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ExpenseCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = ExpenseCategory.values[index];
          final selected = _category == cat;
          return InkWell(
            onTap: () => setState(() => _category = cat),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? cat.color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? cat.color.withValues(alpha: 0.6)
                      : AppColors.textTertiary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.icon,
                    size: 16,
                    color: selected ? cat.color : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.displayName,
                    style: AppTextStyles.bodySm.copyWith(
                      color: selected ? cat.color : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _receiptRow() {
    final attached = _receiptUrl != null;
    return InkWell(
      onTap: _isUploadingReceipt ? null : _pickReceipt,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              attached ? Icons.check_circle : Icons.receipt_long_outlined,
              color: attached ? AppColors.income : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _isUploadingReceipt
                  ? 'Uploading…'
                  : attached
                  ? 'Receipt attached'
                  : 'Attach receipt',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choosePayer() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => GlassContainer(
        sheet: true,
        borderRadius: 24,
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Who paid?', style: AppTextStyles.h3),
            ),
            for (final m in widget.group.members)
              ListTile(
                leading: MemberAvatar(name: m.username, size: 36),
                title: Text(_nameOf(m)),
                trailing: m.id == _payerMemberId
                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, m.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _payerMemberId = picked);
  }

  Future<void> _chooseSplit() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          // Keep this sheet and the expense sheet behind it in step.
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: GlassContainer(
              sheet: true,
              borderRadius: 24,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Split options', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Choose who shares this ${formatRupees(_amount)} '
                    'and how.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<SplitType>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: SplitType.equal,
                        label: Text('Equally'),
                      ),
                      ButtonSegment(
                        value: SplitType.exact,
                        label: Text('Amounts'),
                      ),
                      ButtonSegment(
                        value: SplitType.percentage,
                        label: Text('Percent'),
                      ),
                    ],
                    selected: {_splitType},
                    onSelectionChanged: (v) =>
                        update(() => _splitType = v.first),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in widget.group.members)
                          _shareRow(m, update),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _remainingLine(),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Done',
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shareRow(GroupMember m, void Function(VoidCallback) update) {
    final included = _includedMemberIds.contains(m.id);
    final count = _includedMemberIds.isEmpty ? 1 : _includedMemberIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MemberAvatar(name: m.username, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _nameOf(m),
              style: AppTextStyles.bodyLg.copyWith(
                color: included
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          if (included && _splitType == SplitType.equal)
            Text(
              formatRupees(_amount / count),
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (included)
            SizedBox(
              width: 96,
              child: TextField(
                controller: _shareControllers[m.id],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.right,
                onChanged: (_) => update(() => _error = null),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  prefixText: _splitType == SplitType.percentage ? null : '₹ ',
                  suffixText: _splitType == SplitType.percentage ? ' %' : null,
                ),
              ),
            ),
          Checkbox(
            value: included,
            onChanged: (value) => update(() {
              if (value == true) {
                _includedMemberIds.add(m.id!);
              } else {
                _includedMemberIds.remove(m.id);
              }
            }),
          ),
        ],
      ),
    );
  }

  /// What is still unassigned for exact / percentage splits.
  Widget _remainingLine() {
    if (_splitType == SplitType.equal) {
      final n = _includedMemberIds.length;
      return Text(
        n == 0
            ? 'Pick at least one person.'
            : '${formatRupees(_amount / n)} each, $n '
                  '${n == 1 ? 'person' : 'people'}',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      );
    }
    double entered = 0;
    for (final id in _includedMemberIds) {
      entered += double.tryParse(_shareControllers[id]?.text ?? '') ?? 0;
    }
    final percent = _splitType == SplitType.percentage;
    final target = percent ? 100.0 : _amount;
    final left = target - entered;
    final done = left.abs() < (percent ? 0.01 : 0.5);
    String fmt(double v) => percent ? '${_trim(v)}%' : formatRupees(v);
    return Text(
      done
          ? 'All ${fmt(target)} assigned'
          : left > 0
          ? '${fmt(left)} left of ${fmt(target)}'
          : '${fmt(-left)} over ${fmt(target)}',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyMd.copyWith(
        fontWeight: FontWeight.w600,
        color: done ? AppColors.income : AppColors.outflow,
      ),
    );
  }
}

/// Tappable inline choice in the "Paid by … and split …" sentence.
class _OptionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OptionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
