import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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

/// Axis tick labels shared by the Stats charts.
TextStyle get chartAxisStyle => AppTextStyles.bodySm.copyWith(
  fontSize: 10,
  fontWeight: FontWeight.w500,
  color: AppColors.textSecondary,
);

/// "Last 7 days" with the period's total, above a chart.
class ChartHeader extends StatelessWidget {
  final String caption;
  final String value;

  const ChartHeader({super.key, required this.caption, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.h2),
      ],
    );
  }
}
