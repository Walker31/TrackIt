import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../animated/animated_segmented_tabs.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../ledger_row.dart' show formatRupees;

/// Which way the money went, from the viewer's side.
enum SettleDirection { iPaid, iReceived }

/// Records a payment between the viewer and another member, either way:
/// "I paid them" or "they paid me" (as in Splitwise's settle up).
class SettleUpSheet extends StatefulWidget {
  final int currentMemberId;
  final List<GroupMember> members;
  final List<MemberBalance> balances;
  final Future<void> Function(int fromMemberId, int toMemberId, double amount)
  onSettle;

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
  final _amountController = TextEditingController();
  late SettleDirection _direction;
  int? _otherId;
  bool _isSaving = false;
  String? _error;

  // Keep suggesting amounts until the user types their own.
  bool _amountEdited = false;

  double _balanceFor(int memberId) {
    final match = widget.balances.where((b) => b.memberId == memberId);
    return match.isEmpty ? 0.0 : match.first.balance;
  }

  List<GroupMember> get _others =>
      widget.members.where((m) => m.id != widget.currentMemberId).toList();

  double get _myBalance => _balanceFor(widget.currentMemberId);

  @override
  void initState() {
    super.initState();
    // Positive balance = others owe me, so default to recording a payment
    // received from whoever owes the most; otherwise to paying whoever is
    // owed the most.
    _direction = _myBalance > 0
        ? SettleDirection.iReceived
        : SettleDirection.iPaid;
    _otherId = _suggestedOther()?.id;
    _suggestAmount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  GroupMember? _suggestedOther() {
    final others = _others;
    if (others.isEmpty) return null;
    others.sort((a, b) => _balanceFor(a.id!).compareTo(_balanceFor(b.id!)));
    // Receiving: most negative balance owes the most. Paying: most positive.
    return _direction == SettleDirection.iReceived ? others.first : others.last;
  }

  /// What's outstanding between me and [_otherId] in the chosen direction:
  /// the smaller of what I'm owed (or owe) and what they owe (or are owed).
  double get _suggested {
    final other = _otherId;
    if (other == null) return 0;
    final mine = _myBalance;
    final theirs = _balanceFor(other);
    return switch (_direction) {
      SettleDirection.iReceived when mine > 0 && theirs < 0 =>
        mine < -theirs ? mine : -theirs,
      SettleDirection.iPaid when mine < 0 && theirs > 0 =>
        -mine < theirs ? -mine : theirs,
      _ => 0,
    };
  }

  void _suggestAmount() {
    if (_amountEdited) return;
    final s = _suggested;
    _amountController.text = s > 0
        ? (s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(2))
        : '';
  }

  void _setDirection(SettleDirection d) {
    if (d == _direction) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = d;
      _otherId = _suggestedOther()?.id ?? _otherId;
      _error = null;
      _suggestAmount();
    });
  }

  String _nameOf(int? id) =>
      widget.members.where((m) => m.id == id).firstOrNull?.username ?? '';

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final other = _otherId;
    if (other == null) {
      setState(
        () => _error = _direction == SettleDirection.iPaid
            ? 'Choose who you paid.'
            : 'Choose who paid you.',
      );
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0.');
      return;
    }
    setState(() => _isSaving = true);
    final me = widget.currentMemberId;
    final (from, to) = _direction == SettleDirection.iPaid
        ? (me, other)
        : (other, me);
    await widget.onSettle(from, to, amount);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final others = _others;
    final paid = _direction == SettleDirection.iPaid;
    final otherName = _nameOf(_otherId);
    final outstanding = _suggested;

    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 24,
      sheet: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Settle up", style: AppTextStyles.h2),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSegmentedTabs(
            labels: const ['I paid', 'I received'],
            selectedIndex: _direction.index,
            onChanged: (i) => _setDirection(SettleDirection.values[i]),
          ),
          const SizedBox(height: 20),
          _FlowSummary(
            from: paid ? 'You' : otherName,
            to: paid ? otherName : 'You',
            caption: outstanding > 0
                ? (paid
                      ? 'You owe $otherName ${formatRupees(outstanding)}'
                      : '$otherName owes you ${formatRupees(outstanding)}')
                : (paid
                      ? "You don't owe $otherName anything"
                      : "$otherName doesn't owe you anything"),
          ),
          const SizedBox(height: 20),
          Text(
            paid ? 'Paid to' : 'Received from',
            style: AppTextStyles.fieldLabel,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _otherId,
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
                onChanged: (value) => setState(() {
                  _otherId = value;
                  _suggestAmount();
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.income.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '₹',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  onChanged: (_) => _amountEdited = true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,9}(\.\d{0,2})?'),
                    ),
                  ],
                  cursorColor: AppColors.income,
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: AppTextStyles.h1.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                    ),
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 8, top: 4),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.income, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.expense,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          AppButton(
            text: paid ? 'Record payment' : 'Record payment received',
            isLoading: _isSaving,
            color: AppColors.income,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// "A → B" avatars with a one-line explanation, as in Splitwise.
class _FlowSummary extends StatelessWidget {
  final String from;
  final String to;
  final String caption;

  const _FlowSummary({
    required this.from,
    required this.to,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar(String name) => Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySm,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Row(
              key: ValueKey('$from>$to'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                avatar(from),
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.income,
                  ),
                ),
                avatar(to),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
