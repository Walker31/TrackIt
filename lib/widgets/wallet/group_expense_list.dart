import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/expenses.dart';
import '../empty_state.dart';
import '../ledger_row.dart';
import '../animated/fade_slide_in.dart';

class GroupExpenseList extends StatelessWidget {
  final List<GroupExpense> expenses;

  /// Recorded payments, shown among the expenses like Splitwise.
  final List<Settlement> settlements;
  final List<GroupMember> members;

  /// The viewer's member id in this group, for "you lent / you borrowed".
  final int? currentMemberId;

  /// False offline: rows show what you spent rather than lent / borrowed.
  final bool shared;

  /// Long-press actions (edit / delete).
  final void Function(GroupExpense expense)? onExpenseLongPress;
  final void Function(Settlement settlement)? onSettlementLongPress;

  const GroupExpenseList({
    super.key,
    required this.expenses,
    this.settlements = const [],
    required this.members,
    this.currentMemberId,
    this.shared = true,
    this.onExpenseLongPress,
    this.onSettlementLongPress,
  });

  String _usernameFor(int memberId) {
    final match = members.where((m) => m.id == memberId);
    return match.isEmpty ? 'Unknown' : match.first.username;
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty && settlements.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
        message: 'Tap + to add the first shared expense.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // Newest first across both kinds of entry.
      children: ledgerSections<Object>(
        [...expenses, ...settlements]
          ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a))),
        _dateOf,
        (entry, index) {
          if (entry is Settlement) return _settlementRow(entry, index);
          final e = entry as GroupExpense;
          final me = currentMemberId;
          final iPaid = me != null && e.payerMemberId == me;
          final myShare = e.splits
              .where((s) => s.memberId == me)
              .fold<double>(0, (sum, s) => sum + s.shareAmount);
          final payer = iPaid ? 'You' : _usernameFor(e.payerMemberId);

          // Splitwise: what the expense means for *you*.
          final (label, amount, color) = !shared
              ? ('you spent', e.amount, AppColors.outflow)
              : iPaid
              ? ('you lent', e.amount - myShare, AppColors.income)
              : myShare > 0
              ? ('you borrowed', myShare, AppColors.outflow)
              : ('not involved', null, AppColors.textTertiary);

          return FadeSlideIn(
            index: index,
            child: LedgerRow(
              date: e.timestamp,
              icon: e.category.icon,
              iconColor: e.category.color,
              title: e.description ?? e.category.displayName,
              subtitle: shared
                  ? '$payer paid ${formatRupees(e.amount)}'
                  : e.category.displayName,
              trailingLabel: label,
              trailingAmount: amount == null ? null : formatRupees(amount),
              trailingColor: color,
              onLongPress: onExpenseLongPress == null
                  ? null
                  : () => onExpenseLongPress!(e),
            ),
          );
        },
      ),
    );
  }

  static DateTime _dateOf(Object entry) =>
      entry is Settlement ? entry.timestamp : (entry as GroupExpense).timestamp;

  /// "qa_bob paid you ₹300" with what it means for the viewer.
  Widget _settlementRow(Settlement s, int index) {
    final me = currentMemberId;
    final from = s.fromMemberId == me ? 'You' : _usernameFor(s.fromMemberId);
    final to = s.toMemberId == me ? 'you' : _usernameFor(s.toMemberId);
    final (label, color) = s.toMemberId == me
        ? ('you received', AppColors.income)
        : s.fromMemberId == me
        ? ('you paid', AppColors.outflow)
        : ('not involved', AppColors.textTertiary);
    final involved = s.toMemberId == me || s.fromMemberId == me;

    return FadeSlideIn(
      index: index,
      child: LedgerRow(
        date: s.timestamp,
        icon: Icons.payments_outlined,
        iconColor: AppColors.income,
        title: '$from paid $to ${formatRupees(s.amount)}',
        subtitle: 'Payment',
        trailingLabel: label,
        trailingAmount: involved ? formatRupees(s.amount) : null,
        trailingColor: color,
        onLongPress: onSettlementLongPress == null
            ? null
            : () => onSettlementLongPress!(s),
      ),
    );
  }
}
