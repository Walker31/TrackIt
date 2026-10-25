import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../section_header.dart';
import '../donut_chart.dart';
import '../../models/expenses.dart';
import '../../providers/expense_provider.dart';
import '../animated/fade_slide_in.dart';

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
    final summary = provider.todaySummary;
    final hasData = summary != null && summary.categoryTotals.isNotEmpty;
    final firstLoad = provider.isLoading && summary == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Recent expenses",
          action: TextButton(
            onPressed: onViewAll,
            child: Text(
              "View all",
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (firstLoad)
          const SizedBox(height: 80)
        else if (!hasData)
          _empty("No expenses logged today")
        else ...[
          _buildCategoryOverview(summary),
          const SizedBox(height: 12),
          _buildRecentTransactions(provider.expenses),
        ],
      ],
    );
  }

  Widget _empty(String text) => AppCard(
    child: SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );

  Widget _buildCategoryOverview(DailyExpenseSummary summary) {
    final nonZero = Map.fromEntries(
      summary.categoryTotals.entries.where((e) => e.value > 0),
    );
    if (nonZero.isEmpty) return _empty("No expenses logged today");
    final topCategory = nonZero.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DonutChart(
                  categoryTotals: nonZero,
                  totalAmount: summary.totalAmount,
                  size: 72,
                ),
                Icon(
                  topCategory.key.icon,
                  color: topCategory.key.color,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Top category",
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(topCategory.key.displayName, style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  "₹${summary.totalAmount.toStringAsFixed(0)} today",
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<Expense> expenses) {
    final recent = expenses.take(3).toList();
    return Column(
      children: [
        for (var i = 0; i < recent.length; i++)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: recent[i].category.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      recent[i].category.icon,
                      color: recent[i].category.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recent[i].description ??
                              recent[i].category.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          recent[i].category.displayName,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "-₹${recent[i].amount.toStringAsFixed(0)}",
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
