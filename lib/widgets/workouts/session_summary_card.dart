import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../models/workouts.dart';

class SessionSummaryCard extends StatelessWidget {
  final Workout workout;

  const SessionSummaryCard({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final progress = workout.getSessionCompletionPercentage() / 100;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.type.displayName.toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      workout.notes ?? "Workout Session",
                      style: AppTextStyles.h2,
                    ),
                  ],
                ),
              ),
              Icon(workout.type.icon, color: AppColors.primary, size: 28),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 3,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${workout.getTotalSessionVolume().toStringAsFixed(0)} kg volume",
                style: AppTextStyles.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}% done",
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
