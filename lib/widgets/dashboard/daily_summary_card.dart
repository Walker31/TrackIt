import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../glass_container.dart';
import '../../providers/expense_provider.dart';
import '../../providers/workout_provider.dart';

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
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final expenseSummary = expenseProvider.todaySummary;
    final latestWorkout = workoutProvider.todayWorkout;
    
    double dailySpend = expenseSummary?.totalAmount ?? 0;
    double monthlyBudget = expenseProvider.monthlyBudget;
    double dailyLimit = monthlyBudget / 30;
    double balance = dailyLimit - dailySpend;

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
                  Text("REMAINING DAILY LIMIT", style: AppTextStyles.label.copyWith(color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  Text("₹${balance.toStringAsFixed(0)}", style: AppTextStyles.h1.copyWith(fontSize: 40)),
                ],
              ),
              if (latestWorkout != null)
                _buildProgressIndicator(latestWorkout.getSessionCompletionPercentage()),
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
              const SizedBox(width: 24),
              _buildSummaryItem(
                label: "DAILY SPEND",
                value: "₹${dailySpend.toStringAsFixed(0)}",
                icon: Icons.account_balance_wallet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double percentage) {
    return Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${percentage.toStringAsFixed(0)}%",
            style: AppTextStyles.h3.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text("Done", style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({required String label, required String value, required IconData icon}) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 16),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.label.copyWith(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
