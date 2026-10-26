import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../donut_chart.dart';
import '../../providers/expense_provider.dart';
import '../animated/count_up_text.dart';

/// Spending for the Wallet's selected month, split by the categories the
/// user actually picked.
class FinancialAnalysisCard extends StatelessWidget {
  final ExpenseProvider provider;

  const FinancialAnalysisCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.monthExpenses.isEmpty) {
      return const AppCard(
        child: SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final spend = provider.spendByCategory(provider.monthExpenses);
    final total = spend.fold<double>(0, (sum, e) => sum + e.value);

    if (spend.isEmpty) {
      final month = DateFormat('MMMM yyyy').format(provider.selectedMonth);
      return AppCard(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 36,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text("No spending in $month", style: AppTextStyles.bodyLg),
              Text(
                "Expenses you add for this month show up here",
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Largest first; cap the legend at 4 direct-labeled slices and fold
    // the rest into "Other" so the legend never overflows.
    final shown = spend.take(4).toList();
    final rest = spend.skip(4).fold<double>(0, (sum, e) => sum + e.value);
    final legend = [
      for (final e in shown) (e.key.name, e.key.colorValue, e.value),
      if (rest > 0) ('Other', AppColors.textTertiary, rest),
    ];

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DonutChart(
                  segments: [
                    for (final (_, color, value) in legend)
                      (color: color, value: value),
                  ],
                  totalAmount: total,
                  size: 96,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "SPENT",
                      style: AppTextStyles.label.copyWith(fontSize: 9),
                    ),
                    FittedBox(
                      child: CountUpText(
                        value: total,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
              children: [
                for (final (name, color, value) in legend)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: AppTextStyles.bodySm,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${(value / total * 100).toStringAsFixed(0)}%",
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
