import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A themed surface container. By default it renders as a flat, opaque
/// card (matching the app's light/minimal design). Pass [blur] > 0 for the
/// few spots that genuinely need a frosted overlay floating over other
/// content (the bottom nav bar, the workout rest-timer overlay).
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
    this.borderRadius = 20,
    this.color,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? Theme.of(context).colorScheme.surface;
    final isFrosted = blur > 0;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            border ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (isDark)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: -4,
            ),
        ],
      ),
      child: child,
    );

    if (!isFrosted) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}
