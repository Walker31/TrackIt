import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../utils/format.dart';

class SpendingChart extends StatelessWidget {
  final Map<DateTime, double> data;

  const SpendingChart({super.key, required this.data});

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

    final peak = data.values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = peak <= 0 ? 100.0 : peak * 1.2;
    final interval = niceInterval(maxY);

    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      formatRupees(rod.toY),
                      AppTextStyles.bodySm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.now().subtract(
                          Duration(days: 6 - value.toInt()),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('E').format(date).toUpperCase(),
                            style: AppTextStyles.label.copyWith(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        // Skip the top edge: it's rarely a round number.
                        if (value == meta.max) return const SizedBox.shrink();
                        return Text(
                          formatRupeesCompact(value),
                          style: AppTextStyles.label.copyWith(
                            fontSize: 9,
                            letterSpacing: 0,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.textTertiary.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
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

/// A round gridline step giving about four lines up to [maxY]:
/// 1, 2 or 5 times a power of ten.
double niceInterval(double maxY) {
  final raw = maxY / 4;
  var magnitude = 1.0;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final step in [1.0, 2.0, 5.0, 10.0]) {
    if (magnitude * step >= raw) return magnitude * step;
  }
  return magnitude * 10;
}
