import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../glass_container.dart';
import '../animated/tap_scale.dart';
import '../animated/count_up_text.dart';

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
        ? AppColors.textSecondary
        : (isOwed ? AppColors.income : AppColors.outflow);
    final balanceLabel = isSettled
        ? "Settled up"
        : (isOwed ? "You are owed" : "You owe");

    return TapScale(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(group.icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${group.members.length} member${group.members.length == 1 ? '' : 's'}",
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  balanceLabel,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                CountUpText(
                  value: myBalance.abs(),
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.bold,
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
