import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../section_header.dart';
import '../../models/workouts.dart';
import '../../providers/workout_provider.dart';
import '../animated/fade_slide_in.dart';

class FitnessGoalSection extends StatelessWidget {
  final WorkoutProvider provider;
  final VoidCallback onViewAll;

  const FitnessGoalSection({
    super.key,
    required this.provider,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final workout = provider.todayWorkout;
    final firstLoad = provider.isLoading && workout == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's workout",
          action: TextButton(
            onPressed: onViewAll,
            child: Text(
              "View all",
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (firstLoad)
          const SizedBox(height: 80)
        else if (workout == null || workout.exercises.isEmpty)
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: Text(
                "No exercises logged today",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < workout.exercises.take(2).length; i++)
                FadeSlideIn(
                  index: i,
                  child: _buildExerciseCard(workout.exercises[i]),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final progress = exercise.getCompletionPercentage() / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        exercise.muscleGroup,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${exercise.getCompletedSetsCount()}/${exercise.sets.length} sets",
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
