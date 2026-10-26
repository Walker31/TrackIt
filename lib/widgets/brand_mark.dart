import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The TrackIt logo: the target glyph on a rounded gradient tile.
class BrandMark extends StatelessWidget {
  final double size;

  /// Draw the tile in white (for use on the gradient brand panel).
  final bool onGradient;

  const BrandMark({super.key, this.size = 56, this.onGradient = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onGradient ? null : AppColors.primaryGradient,
        color: onGradient ? Colors.white.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: onGradient
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
        boxShadow: onGradient
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: size * 0.4,
                  offset: Offset(0, size * 0.12),
                ),
              ],
      ),
      child: Icon(
        Icons.track_changes_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
