import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../glass_container.dart';
import '../../providers/expense_provider.dart';
import '../../providers/workout_provider.dart';
import '../animated/count_up_text.dart';

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
    if (expenseProvider.isLoading || workoutProvider.isLoading) {
      return const AppCard(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final latestWorkout = workoutProvider.todayWorkout;
    final todaySpend = expenseProvider.todaySummary?.totalAmount ?? 0;

    double monthlySpend = expenseProvider.monthlySpent;
    double monthlyBudget = expenseProvider.monthlyBudget;
    double balance = monthlyBudget - monthlySpend;

    return AppCard(
      gradient: AppColors.primaryGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "REMAINING MONTHLY LIMIT",
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CountUpText(
                    value: balance,
                    style: AppTextStyles.h1.copyWith(fontSize: 40),
                  ),
                ],
              ),
              if (latestWorkout != null)
                _buildProgressIndicator(
                  latestWorkout.getSessionCompletionPercentage(),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildSummaryItem(
                label: "WORKOUT",
                value: latestWorkout?.type.displayName ?? "Rest Day",
                icon: Icons.fitness_center,
              ),
              const SizedBox(width: 12),
              _buildSummaryItem(
                label: "TODAY SPEND",
                value: "₹${todaySpend.toStringAsFixed(0)}",
                icon: Icons.today,
              ),
              const SizedBox(width: 12),
              _buildSummaryItem(
                label: "MONTH SPEND",
                value: "₹${monthlySpend.toStringAsFixed(0)}",
                icon: Icons.account_balance_wallet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double percentage) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentage / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: animatedValue,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${(animatedValue * 100).toStringAsFixed(0)}%",
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text("Done", style: AppTextStyles.bodySm),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        color: Colors.white,
        opacity: 0.15,
        blur: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 16),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.bodyLg.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
