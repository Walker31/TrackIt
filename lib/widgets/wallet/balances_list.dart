import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../../utils/format.dart';
import '../app_card.dart';
import '../empty_state.dart';
import '../member_avatar.dart';
import '../animated/fade_slide_in.dart';

/// Each member's net position in the event, worded like Splitwise:
/// "Asha gets back ₹400", "Ravi owes ₹250", "You are settled up".
class BalancesList extends StatelessWidget {
  final List<MemberBalance> balances;
  final int currentMemberId;

  const BalancesList({
    super.key,
    required this.balances,
    required this.currentMemberId,
  });

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return const EmptyState(
        icon: Icons.balance_rounded,
        title: 'Everyone is settled up',
        message: 'Balances appear once expenses are shared.',
      );
    }

    return FadeSlideIn(
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < balances.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 70),
              _row(balances[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(MemberBalance b) {
    final isMe = b.memberId == currentMemberId;
    final name = isMe ? 'You' : b.username;
    final isSettled = b.balance.abs() < 0.01;
    final isOwed = b.balance > 0;

    final (verb, color) = isSettled
        ? (isMe ? ' are settled up' : ' is settled up', AppColors.textTertiary)
        : isOwed
        ? (isMe ? ' get back ' : ' gets back ', AppColors.income)
        : (isMe ? ' owe ' : ' owes ', AppColors.outflow);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          MemberAvatar(name: b.username),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTextStyles.bodyLg.copyWith(
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: verb,
                    style: TextStyle(
                      color: isSettled ? AppColors.textSecondary : color,
                    ),
                  ),
                  if (!isSettled)
                    TextSpan(
                      text: formatRupees(b.balance.abs()),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
