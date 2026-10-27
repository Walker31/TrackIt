import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../animated/count_up_text.dart';

/// One event in the events list, Splitwise-style: a square emoji tile,
/// the name and member count, and what the event means for you on the
/// right ("you are owed" / "you owe" / "settled up").
class GroupCard extends StatelessWidget {
  final Group group;
  final double myBalance;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.myBalance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSettled = myBalance.abs() < 0.01;
    final isOwed = myBalance > 0;
    final balanceColor = isSettled
        ? AppColors.textTertiary
        : (isOwed ? AppColors.income : AppColors.outflow);
    final members = group.members.length;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(group.icon, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$members member${members == 1 ? '' : 's'}',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            isSettled
                ? Text(
                    'settled up',
                    style: AppTextStyles.bodySm.copyWith(color: balanceColor),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isOwed ? 'you are owed' : 'you owe',
                        style: AppTextStyles.bodySm.copyWith(
                          color: balanceColor,
                          fontSize: 12,
                        ),
                      ),
                      CountUpText(
                        value: myBalance.abs(),
                        style: AppTextStyles.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
