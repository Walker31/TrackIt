import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../empty_state.dart';
import '../section_header.dart';
import '../donut_chart.dart';
import '../../models/expenses.dart';
import '../../utils/format.dart';
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
    final hasData = provider.expenses.isNotEmpty;
    final firstLoad = provider.isLoading && summary == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's spending",
          action: TextButton(
            onPressed: onViewAll,
            child: const Text("View all"),
          ),
        ),
        const SizedBox(height: 8),
        if (firstLoad)
          const SizedBox(height: 80)
        else if (!hasData)
          _empty()
        else ...[
          _buildCategoryOverview(),
          const SizedBox(height: 12),
          _buildRecentTransactions(provider.expenses),
        ],
      ],
    );
  }

  Widget _empty() => const EmptyState(
    card: true,
    compact: true,
    icon: Icons.receipt_long_outlined,
    title: 'Nothing spent today',
    message: 'Expenses you add today show up here.',
  );

  Widget _buildCategoryOverview() {
    final spend = provider.spendByCategory(provider.expenses);
    if (spend.isEmpty) return _empty();
    final total = spend.fold<double>(0, (sum, e) => sum + e.value);
    final top = spend.first.key;

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
                  segments: [
                    for (final e in spend)
                      (color: e.key.colorValue, value: e.value),
                  ],
                  totalAmount: total,
                  size: 72,
                ),
                Icon(top.iconData, color: top.colorValue, size: 20),
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
                Text(top.name, style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  "${formatRupees(total)} today",
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
    final categories = [for (final e in recent) provider.categoryOf(e)];
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
                      color: categories[i].colorValue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categories[i].iconData,
                      color: categories[i].colorValue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recent[i].description ?? categories[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          categories[i].name,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${recent[i].isIncome ? '+' : '-'}"
                    "${formatRupees(recent[i].amount)}",
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
