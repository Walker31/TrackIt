import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../glass_container.dart';
import '../animated/fade_slide_in.dart';
import '../animated/count_up_text.dart';

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
      return const Center(child: Text("No balances yet"));
    }

    return Column(
      children: balances.asMap().entries.map((entry) {
        final index = entry.key;
        final b = entry.value;
        final isMe = b.memberId == currentMemberId;
        final isSettled = b.balance.abs() < 0.01;
        final isOwed = b.balance > 0;
        final color = isSettled
            ? AppColors.textSecondary
            : (isOwed ? AppColors.income : AppColors.expense);

        return FadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      b.username.isNotEmpty ? b.username[0].toUpperCase() : '?',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isMe ? "${b.username} (you)" : b.username,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  isSettled
                      ? Text(
                          "Settled up",
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        )
                      : CountUpText(
                          value: b.balance.abs(),
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
