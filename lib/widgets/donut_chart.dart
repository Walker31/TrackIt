import 'package:flutter/material.dart';
import '../models/expenses.dart';

class DonutChart extends StatelessWidget {
  final Map<ExpenseCategory, double> categoryTotals;
  final double totalAmount;
  final double size;

  const DonutChart({
    super.key,
    required this.categoryTotals,
    required this.totalAmount,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: DonutChartPainter(categoryTotals, totalAmount),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<ExpenseCategory, double> categoryTotals;
  final double totalAmount;

  DonutChartPainter(this.categoryTotals, this.totalAmount);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (paint.strokeWidth / 2);

    if (totalAmount == 0) {
      paint.color = Colors.grey.withValues(alpha:0.1);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -1.5708; // -90 degrees

    categoryTotals.forEach((category, amount) {
      final sweepAngle = (amount / totalAmount) * (2 * 3.14159265359);
      paint.color = category.color;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      
      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
