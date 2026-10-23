import 'package:flutter/material.dart';
import '../../models/expenses.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../donut_chart.dart';
import '../../providers/expense_provider.dart';
import '../animated/count_up_text.dart';

class FinancialAnalysisCard extends StatelessWidget {
  final ExpenseProvider provider;

  const FinancialAnalysisCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const AppCard(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final summary = provider.todaySummary;
    final List<MapEntry<ExpenseCategory, double>> nonZeroCategories =
        summary?.categoryTotals.entries.where((e) => e.value > 0).toList() ??
        <MapEntry<ExpenseCategory, double>>[];

    if (summary == null ||
        summary.totalAmount <= 0 ||
        nonZeroCategories.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text("No transactions yet", style: AppTextStyles.bodyLg),
            const Text(
              "Start tracking your expenses",
              style: AppTextStyles.bodySm,
            ),
          ],
        ),
      );
    }

    // Sort largest-first and cap the legend at 4 direct-labeled slices;
    // anything smaller folds into "Other" so the legend never overflows.
    final sorted = nonZeroCategories.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(4).toList();

    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DonutChart(
                      categoryTotals: summary.categoryTotals,
                      totalAmount: summary.totalAmount,
                      size: 96,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "SPENT",
                          style: AppTextStyles.label.copyWith(fontSize: 9),
                        ),
                        CountUpText(
                          value: summary.totalAmount,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: shown.map((e) {
                    final percentage = summary.totalAmount > 0
                        ? (e.value / summary.totalAmount) * 100
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: e.key.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key.displayName,
                              style: AppTextStyles.bodySm,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${percentage.toStringAsFixed(0)}%",
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
