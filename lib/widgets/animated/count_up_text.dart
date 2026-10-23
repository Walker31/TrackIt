import 'package:flutter/material.dart';

/// Animates a rupee amount counting up from 0 (or its previous value) to
/// [value] whenever it changes.
class CountUpText extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final int decimals;

  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '₹',
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(decimals)}',
          style: style,
        );
      },
    );
  }
}
