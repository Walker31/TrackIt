import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/expenses.dart';
import '../ledger_row.dart';
import '../animated/fade_slide_in.dart';

class GroupExpenseList extends StatelessWidget {
  final List<GroupExpense> expenses;
  final List<GroupMember> members;

  /// The viewer's member id in this group, for "you lent / you borrowed".
  final int? currentMemberId;

  const GroupExpenseList({
    super.key,
    required this.expenses,
    required this.members,
    this.currentMemberId,
  });

  String _usernameFor(int memberId) {
    final match = members.where((m) => m.id == memberId);
    return match.isEmpty ? 'Unknown' : match.first.username;
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(child: Text("No expenses yet"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ledgerSections<GroupExpense>(expenses, (e) => e.timestamp, (
        e,
        index,
      ) {
        final me = currentMemberId;
        final iPaid = me != null && e.payerMemberId == me;
        final myShare = e.splits
            .where((s) => s.memberId == me)
            .fold<double>(0, (sum, s) => sum + s.shareAmount);
        final payer = iPaid ? 'You' : _usernameFor(e.payerMemberId);

        // Splitwise: what the expense means for *you*.
        final (label, amount, color) = iPaid
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
            subtitle: '$payer paid ${formatRupees(e.amount)}',
            trailingLabel: label,
            trailingAmount: amount == null ? null : formatRupees(amount),
            trailingColor: color,
          ),
        );
      }),
    );
  }
}
