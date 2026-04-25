import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass_container.dart';
import '../../providers/workout_provider.dart';

class RestTimerOverlay extends StatelessWidget {
  final WorkoutProvider provider;

  const RestTimerOverlay({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      blur: 20,
      opacity: 0.2,
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.secondary),
          const SizedBox(width: 12),
          Text("REST TIMER", style: AppTextStyles.label.copyWith(color: AppColors.secondary)),
          const Spacer(),
          Text(
            "${provider.restTimeRemaining}s",
            style: AppTextStyles.h3.copyWith(color: Colors.white),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => provider.cancelTimer(),
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
