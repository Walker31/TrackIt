import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/stats_service.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../empty_state.dart';
import 'spending_chart.dart' show niceInterval, chartAxisStyle, ChartHeader;

/// Bars for a [StatsRange]: days for a week or month, months for a year.
/// Tapping a bar calls [onTapBar] with its bucket.
class RangeBarChart extends StatefulWidget {
  final List<StatPoint> points;
  final StatsRange range;
  final Color color;
  final String Function(double) format;
  final String Function(double) formatAxis;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final void Function(StatPoint point)? onTapBar;

  /// Read out with the total, e.g. "spent".
  final String semanticNoun;

  const RangeBarChart({
    super.key,
    required this.points,
    required this.range,
    required this.color,
    required this.format,
    required this.formatAxis,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.semanticNoun,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onTapBar,
  });

  @override
  State<RangeBarChart> createState() => _RangeBarChartState();
}

class _RangeBarChartState extends State<RangeBarChart> {
  int? _touched;

  String _label(DateTime d) => switch (widget.range) {
    StatsRange.week => DateFormat('E').format(d).toUpperCase(),
    StatsRange.month => '${d.day}',
    StatsRange.year => DateFormat('MMM').format(d).substring(0, 1),
  };

  String _longLabel(DateTime d) => widget.range.monthly
      ? DateFormat('MMMM yyyy').format(d)
      : DateFormat('EEE d MMM').format(d);

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final peak = points.fold<double>(0, (a, p) => p.value > a ? p.value : a);
    if (peak <= 0) {
      return EmptyState(
        card: true,
        icon: Icons.bar_chart_rounded,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        actionLabel: widget.emptyActionLabel,
        onAction: widget.onEmptyAction,
      );
    }
    final total = points.fold<double>(0, (a, p) => a + p.value);
    final active = points.where((p) => p.value > 0).length;
    final maxY = peak * 1.2;
    final interval = niceInterval(maxY);
    final many = points.length > 12;
    final barWidth = switch (widget.range) {
      StatsRange.week => 18.0,
      StatsRange.month => 6.0,
      StatsRange.year => 14.0,
    };
    final best = points.reduce((a, b) => b.value > a.value ? b : a);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChartHeader(
            caption: widget.range.caption,
            value: widget.format(total),
          ),
          const SizedBox(height: 4),
          Text(
            widget.range.monthly
                ? 'Average ${widget.format(total / points.length)} a month · '
                      'peak in ${DateFormat('MMMM').format(best.start)}'
                : 'Average ${widget.format(total / points.length)} a day · '
                      '$active active ${active == 1 ? 'day' : 'days'}',
            style: AppTextStyles.bodySm.copyWith(color: chartAxisStyle.color),
          ),
          const SizedBox(height: 16),
          Semantics(
            label:
                '${widget.range.caption}: ${widget.format(total)} '
                '${widget.semanticNoun}. Highest: ${_longLabel(best.start)}, '
                '${widget.format(best.value)}.',
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchCallback: (event, response) {
                      final i = response?.spot?.touchedBarGroupIndex;
                      if (i == null) return;
                      if (event is FlTapUpEvent &&
                          widget.onTapBar != null &&
                          points[i].value > 0) {
                        widget.onTapBar!(points[i]);
                      }
                      if (_touched != i) setState(() => _touched = i);
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${_longLabel(points[group.x].start)}\n'
                        '${widget.format(rod.toY)}',
                        AppTextStyles.bodySm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          // A month of days: label every fifth, and today.
                          if (many && i % 5 != 4 && i != points.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _label(points[i].start),
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
                          if (value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            widget.formatAxis(value),
                            style: chartAxisStyle,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: chartAxisStyle.color!.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].value,
                            color: _touched == null || _touched == i
                                ? widget.color
                                : widget.color.withValues(alpha: 0.45),
                            width: barWidth,
                            borderRadius: BorderRadius.circular(barWidth / 4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.onTapBar != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.range.monthly
                  ? 'Tap a month to see its transactions.'
                  : 'Tap a day to see its transactions.',
              style: chartAxisStyle,
            ),
          ],
        ],
      ),
    );
  }
}
