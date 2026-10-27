import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../app_card.dart';
import '../empty_state.dart';
import 'spending_chart.dart' show niceInterval, chartAxisStyle, ChartHeader;

class VolumeChart extends StatelessWidget {
  final Map<DateTime, double> data;

  const VolumeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.entries.map((e) {
      final dayIndex = (6 - DateTime.now().difference(e.key).inDays).toDouble();
      return FlSpot(dayIndex, e.value);
    }).toList();

    final peak = data.values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = peak <= 0 ? 100.0 : peak * 1.2;
    final interval = niceInterval(maxY);

    final total = data.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return const EmptyState(
        card: true,
        icon: Icons.show_chart_rounded,
        title: 'No training this week',
        message: 'Complete sets in the Workout tab to see your volume.',
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChartHeader(
            caption: 'Last 7 days',
            value:
                '${NumberFormat.decimalPattern('en_IN').format(total.round())} kg',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.textTertiary.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // One label per day; without this fl_chart picks
                      // half-day steps and every day appears twice.
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.now().subtract(
                          Duration(days: 6 - value.toInt()),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('E').format(date).toUpperCase(),
                            style: chartAxisStyle,
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
                          '${value.toStringAsFixed(0)} kg',
                          style: chartAxisStyle,
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
