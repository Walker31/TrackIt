import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../section_header.dart';
import '../glass_container.dart';
import '../../models/expenses.dart';
import '../../providers/expense_provider.dart';

class RecentExpensesSection extends StatelessWidget {
  final ExpenseProvider provider;
  final VoidCallback onViewAll;

  const RecentExpensesSection({
    super.key,
    required this.provider,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Recent Expenses",
          subtitle: "Wallet",
          action: TextButton(
            onPressed: onViewAll,
            child: const Text("View All", style: TextStyle(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 16),
        if (provider.isLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (provider.todaySummary == null || provider.todaySummary!.categoryTotals.isEmpty)
          const AppCard(child: Center(child: Text("No expenses logged today")))
        else
          Column(
            children: [
              _buildCategoryOverview(provider.todaySummary!),
              const SizedBox(height: 16),
              _buildRecentTransactions(provider.expenses),
            ],
          ),
      ],
    );
  }

  Widget _buildCategoryOverview(DailyExpenseSummary summary) {
    var topCategory = summary.categoryTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return AppCard(
      child: Row(
        children: [
          _buildDonutChart(0.65), // Mock value for now
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TOP CATEGORY", style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(topCategory.key.displayName, style: AppTextStyles.h3),
                const SizedBox(height: 12),
                Text("Total Today", style: AppTextStyles.bodyMd),
                Text("₹${summary.totalAmount.toStringAsFixed(0)}", 
                  style: AppTextStyles.h2.copyWith(color: AppColors.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(double value) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 8,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
          ),
          const Center(
            child: Icon(Icons.shopping_bag_outlined, color: AppColors.secondary, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<Expense> expenses) {
    final recent = expenses.take(3).toList();
    return Column(
      children: recent.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: e.category.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(e.category.icon, color: e.category.color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.description ?? e.category.displayName, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                    Text(e.category.displayName, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text("-₹${e.amount.toStringAsFixed(0)}", 
                style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.expense)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}
