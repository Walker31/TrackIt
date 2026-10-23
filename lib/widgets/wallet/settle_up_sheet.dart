import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../glass_container.dart';
import '../app_button.dart';

class SettleUpSheet extends StatefulWidget {
  final int currentMemberId;
  final List<GroupMember> members;
  final List<MemberBalance> balances;
  final Future<void> Function(int toMemberId, double amount) onSettle;

  const SettleUpSheet({
    super.key,
    required this.currentMemberId,
    required this.members,
    required this.balances,
    required this.onSettle,
  });

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  late final TextEditingController _amountController;
  int? _toMemberId;
  bool _isSaving = false;
  String? _error;

  double _balanceFor(int memberId) {
    final match = widget.balances.where((b) => b.memberId == memberId);
    return match.isEmpty ? 0.0 : match.first.balance;
  }

  @override
  void initState() {
    super.initState();
    final others = widget.members
        .where((m) => m.id != widget.currentMemberId)
        .toList();
    final myBalance = _balanceFor(widget.currentMemberId);

    // Default to the person the current user owes the most, if any.
    GroupMember? suggestion;
    if (myBalance < 0 && others.isNotEmpty) {
      others.sort((a, b) => _balanceFor(a.id!).compareTo(_balanceFor(b.id!)));
      suggestion = others.last;
    }
    _toMemberId = (suggestion ?? (others.isNotEmpty ? others.first : null))?.id;

    final cap = _toMemberId != null ? _balanceFor(_toMemberId!).abs() : 0.0;
    final suggestedAmount = myBalance < 0
        ? myBalance.abs().clamp(0.0, cap == 0.0 ? myBalance.abs() : cap)
        : 0.0;
    _amountController = TextEditingController(
      text: suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.members
        .where((m) => m.id != widget.currentMemberId)
        .toList();

    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Settle Up", style: AppTextStyles.h2),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text("Pay to", style: AppTextStyles.label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _toMemberId,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                ),
                items: others
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.username),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _toMemberId = value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.h1.copyWith(color: AppColors.income),
            decoration: const InputDecoration(
              prefixText: "₹",
              hintText: "0.00",
              border: InputBorder.none,
            ),
          ),
          if (_error != null) ...[
            Text(
              _error!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.expense),
            ),
          ],
          const SizedBox(height: 32),
          AppButton(
            text: _isSaving ? "Recording..." : "Record Settlement",
            color: AppColors.income,
            onPressed: _isSaving
                ? () {}
                : () async {
                    final amount =
                        double.tryParse(_amountController.text) ?? 0.0;
                    if (_toMemberId == null) {
                      setState(() => _error = 'Choose who you are paying.');
                      return;
                    }
                    if (amount <= 0) {
                      setState(
                        () => _error = 'Enter an amount greater than 0.',
                      );
                      return;
                    }
                    setState(() => _isSaving = true);
                    await widget.onSettle(_toMemberId!, amount);
                    if (context.mounted) Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}
