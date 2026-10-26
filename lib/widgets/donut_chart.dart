import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// One slice: its color and amount.
typedef DonutSegment = ({Color color, double value});

/// A donut chart of category spend, animating its arcs in on first paint.
/// Segments get a small gap between them (dataviz mark spec: a visible
/// surface gap between adjacent fills) so slices read as distinct even
/// before color is considered.
class DonutChart extends StatefulWidget {
  final List<DonutSegment> segments;
  final double totalAmount;
  final double size;

  const DonutChart({
    super.key,
    required this.segments,
    required this.totalAmount,
    this.size = 200,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: DonutChartPainter(
            widget.segments,
            widget.totalAmount,
            progress: curved.value,
            emptyColor: AppColors.surfaceVariant,
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double totalAmount;
  final double progress;
  final Color emptyColor;

  DonutChartPainter(
    this.segments,
    this.totalAmount, {
    this.progress = 1.0,
    required this.emptyColor,
  });

  static const double _gapRadians = 0.045;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (paint.strokeWidth / 2);

    if (totalAmount == 0) {
      paint.color = emptyColor;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    for (final segment in segments) {
      final rawSweep = (segment.value / totalAmount) * fullSweep;
      // A single slice is a full ring; only separate slices get a gap.
      final gap = segments.length > 1 ? _gapRadians : 0.0;
      final sweepAngle = (rawSweep - gap).clamp(0.0, fullSweep) * progress;
      paint.color = segment.color;

      if (sweepAngle > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
      }

      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.segments != segments ||
      oldDelegate.totalAmount != totalAmount;
}
