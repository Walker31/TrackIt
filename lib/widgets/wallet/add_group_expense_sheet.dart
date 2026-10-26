import '../expense_entry_fields.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../../services/cloudinary_service.dart';
import '../glass_container.dart';
import '../app_button.dart';

class AddGroupExpenseSheet extends StatefulWidget {
  final Group group;
  final int? defaultPayerMemberId;
  final Future<void> Function(GroupExpense expense) onAdd;

  const AddGroupExpenseSheet({
    super.key,
    required this.group,
    required this.onAdd,
    this.defaultPayerMemberId,
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
  }

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
    if (_amount <= 0 || splits.isEmpty) {
      setState(
        () => _error = 'Enter an amount and select at least one member.',
      );
      return;
    }

    if (_splitType != SplitType.equal) {
      final total = splits.fold<double>(0, (sum, s) => sum + s.shareAmount);
      if ((total - _amount).abs() > 0.5) {
        setState(
          () => _error = _splitType == SplitType.percentage
              ? 'Percentages must add up to 100%.'
              : 'Shares must add up to the total amount.',
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
        groupId: widget.group.id!,
        payerMemberId: _payerMemberId,
        amount: _amount,
        category: _category,
        description: _descController.text.isEmpty ? null : _descController.text,
        timestamp: DateTime.now(),
        receiptUrl: _receiptUrl,
        splitType: _splitType,
        splits: splits,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                const Text("Add Expense", style: AppTextStyles.h2),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ExpenseEntryFields(
              descriptionController: _descController,
              amountController: _amountController,
              icon: _category.icon,
              iconColor: _category.color,
              accent: AppColors.expense,
              onAmountChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Text("Paid by", style: AppTextStyles.label),
            const SizedBox(height: 8),
            _buildMemberDropdown(),
            const SizedBox(height: 20),
            Text("Category", style: AppTextStyles.label),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ExpenseCategory.values.length,
                itemBuilder: (context, index) {
                  final cat = ExpenseCategory.values[index];
                  final isSelected = _category == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.displayName),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = cat),
                      selectedColor: cat.color.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? cat.color : AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text("Split", style: AppTextStyles.label),
            const SizedBox(height: 12),
            Row(
              children: SplitType.values.map((type) {
                final isSelected = _splitType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_splitLabel(type)),
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _splitType = type),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ...widget.group.members.map(_buildMemberShareRow),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isUploadingReceipt ? null : _pickReceipt,
              child: Row(
                children: [
                  Icon(
                    _receiptUrl != null
                        ? Icons.check_circle
                        : Icons.receipt_long_outlined,
                    color: _receiptUrl != null
                        ? AppColors.income
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUploadingReceipt
                        ? "Uploading..."
                        : (_receiptUrl != null
                              ? "Receipt attached"
                              : "Attach receipt"),
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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
              text: _isSaving ? "Saving..." : "Save Expense",
              color: AppColors.expense,
              onPressed: _isSaving ? () {} : _save,
            ),
          ],
        ),
      ),
    );
  }

  String _splitLabel(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return "Equal";
      case SplitType.exact:
        return "Exact";
      case SplitType.percentage:
        return "Percentage";
    }
  }

  Widget _buildMemberDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _payerMemberId,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textPrimary),
          items: widget.group.members
              .map(
                (m) => DropdownMenuItem(value: m.id, child: Text(m.username)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _payerMemberId = value);
          },
        ),
      ),
    );
  }

  Widget _buildMemberShareRow(GroupMember member) {
    final included = _includedMemberIds.contains(member.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: included,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _includedMemberIds.add(member.id!);
                } else {
                  _includedMemberIds.remove(member.id);
                }
              });
            },
          ),
          Expanded(child: Text(member.username, style: AppTextStyles.bodyMd)),
          if (_splitType != SplitType.equal && included)
            SizedBox(
              width: 90,
              child: TextField(
                controller: _shareControllers[member.id],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: _splitType == SplitType.percentage ? "%" : "₹",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            )
          else if (included)
            Text(
              "₹${(_amount / (_includedMemberIds.isEmpty ? 1 : _includedMemberIds.length)).toStringAsFixed(0)}",
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
