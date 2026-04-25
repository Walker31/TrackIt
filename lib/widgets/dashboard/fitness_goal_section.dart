import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../section_header.dart';
import '../../models/workouts.dart';
import '../../providers/workout_provider.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Fitness Goal",
          subtitle: "Workout",
          action: TextButton(
            onPressed: onViewAll,
            child: const Text("View All", style: TextStyle(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 16),
        if (provider.isLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (provider.todayWorkout == null || provider.todayWorkout!.exercises.isEmpty)
          const AppCard(child: Center(child: Text("No exercises logged today")))
        else
          Column(
            children: provider.todayWorkout!.exercises.take(2).map((e) => _buildExerciseCard(e)).toList(),
          ),
      ],
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final progress = exercise.getCompletionPercentage() / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                      Text(exercise.muscleGroup, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text("${exercise.getCompletedSetsCount()}/${exercise.sets.length} Sets", 
                  style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
