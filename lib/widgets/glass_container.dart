import 'dart:ui';
import 'package:flutter/material.dart';

/// A themed surface container. By default it renders as a flat, opaque
/// card with a hairline border. Pass [blur] > 0 for the few spots that
/// genuinely need a frosted overlay floating over other content (the
/// workout rest-timer overlay).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Color? color;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 0,
    this.opacity = 1,
    this.borderRadius = 16,
    this.color,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? Theme.of(context).colorScheme.surface;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            border ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );
  }
}
