import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../providers/expense_provider.dart';

class FinancialAnalysisCard extends StatelessWidget {
  final ExpenseProvider provider;

  const FinancialAnalysisCard({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const AppCard(child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final summary = provider.todaySummary;
    if (summary == null || summary.categoryTotals.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text("No transactions yet", style: AppTextStyles.bodyLg),
            const Text("Start tracking your expenses", style: AppTextStyles.bodySm),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("Spent Today", "₹${summary.totalAmount.toStringAsFixed(0)}", AppColors.expense),
              _buildStatItem("Top Category", summary.categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key.displayName, AppColors.primary),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          Row(
            children: summary.categoryTotals.entries.take(4).map((e) {
              final percentage = e.value / summary.totalAmount;
              return Expanded(
                child: Column(
                  children: [
                    Text("${(percentage * 100).toStringAsFixed(0)}%", style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: e.key.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(e.key.icon, color: e.key.color, size: 16),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.h2.copyWith(color: valueColor)),
      ],
    );
  }
}
