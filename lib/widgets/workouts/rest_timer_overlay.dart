import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/format.dart';
import '../glass_container.dart';
import '../../providers/workout_provider.dart';

class RestTimerOverlay extends StatelessWidget {
  final WorkoutProvider provider;

  const RestTimerOverlay({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final total = provider.restTotal <= 0 ? 1 : provider.restTotal;
    final left = provider.restTimeRemaining;
    return Semantics(
      liveRegion: true,
      label: 'Rest timer, ${formatDuration(left)} left',
      child: GlassContainer(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        borderRadius: 16,
        blur: 20,
        opacity: 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: AppColors.secondary),
                const SizedBox(width: 10),
                Text(
                  "REST",
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const Spacer(),
                _Adjust(
                  label: '−15',
                  tooltip: 'Remove 15 seconds',
                  onTap: () => provider.adjustRestTimer(-15),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDuration(left),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                _Adjust(
                  label: '+15',
                  tooltip: 'Add 15 seconds',
                  onTap: () => provider.adjustRestTimer(15),
                ),
                IconButton(
                  tooltip: 'Skip rest',
                  onPressed: () => provider.cancelTimer(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (left / total).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(AppColors.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Adjust extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _Adjust({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: AppTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}
