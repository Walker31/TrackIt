import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../providers/expense_provider.dart';
import '../../providers/workout_provider.dart';
import '../animated/count_up_text.dart';
import '../../utils/format.dart';

class DailySummaryCard extends StatelessWidget {
  final ExpenseProvider expenseProvider;
  final WorkoutProvider workoutProvider;

  const DailySummaryCard({
    super.key,
    required this.expenseProvider,
    required this.workoutProvider,
  });

  @override
  Widget build(BuildContext context) {
    final firstLoad =
        (expenseProvider.isLoading || workoutProvider.isLoading) &&
        expenseProvider.todaySummary == null;
    if (firstLoad) {
      return const AppCard(
        child: SizedBox(
          height: 150,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final latestWorkout = workoutProvider.todayWorkout;
    final todaySpend = expenseProvider.todaySummary?.totalAmount ?? 0;
    final monthlySpend = expenseProvider.monthlySpent;
    final monthlyBudget = expenseProvider.monthlyBudget;
    final balance = monthlyBudget - monthlySpend;
    final over = balance < 0;
    final used = monthlyBudget <= 0
        ? 0.0
        : (monthlySpend / monthlyBudget).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPENT THIS MONTH', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          CountUpText(
            value: monthlySpend,
            style: AppTextStyles.h1.copyWith(
              fontSize: 38,
              color: over ? AppColors.outflow : AppColors.textPrimary,
            ),
          ),
          if (monthlyBudget > 0)
            Text(
              'of ${formatRupees(monthlyBudget)} monthly budget',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: used),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(
                  over ? AppColors.outflow : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _stat('Today', formatRupees(todaySpend)),
              _stat(over ? 'Over budget' : 'Left', formatRupees(balance.abs())),
              _stat(
                'Workout',
                latestWorkout == null
                    ? 'Rest day'
                    : '${latestWorkout.getSessionCompletionPercentage().toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
