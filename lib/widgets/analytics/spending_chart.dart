import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';

class SpendingChart extends StatelessWidget {
  final Map<DateTime, double> data;

  const SpendingChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final spots = data.entries.map((e) {
      final dayIndex = 6 - DateTime.now().difference(e.key).inDays;
      return BarChartGroupData(
        x: dayIndex,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: AppColors.secondary,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: data.values.isEmpty ? 100 : data.values.reduce((a, b) => a > b ? a : b) * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(DateFormat('E').format(date).toUpperCase(), style: AppTextStyles.label.copyWith(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: spots,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Last 7 Days Spending", style: AppTextStyles.bodySm),
        ],
      ),
    );
  }
}
