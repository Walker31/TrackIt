import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../glass_container.dart';
import '../app_button.dart';
import '../app_snackbar.dart';
import '../../models/workouts.dart';
import '../../providers/workout_provider.dart';

class ActiveExerciseTracker extends StatelessWidget {
  final Exercise exercise;
  final WorkoutProvider provider;
  final double weight;
  final int reps;
  final VoidCallback onWeightDec;
  final VoidCallback onWeightInc;
  final VoidCallback onRepsDec;
  final VoidCallback onRepsInc;

  const ActiveExerciseTracker({
    super.key,
    required this.exercise,
    required this.provider,
    required this.weight,
    required this.reps,
    required this.onWeightDec,
    required this.onWeightInc,
    required this.onRepsDec,
    required this.onRepsInc,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(exercise.name, style: AppTextStyles.h3),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMetricPicker(
                "Weight",
                "${weight.toStringAsFixed(1)} kg",
                onWeightDec,
                onWeightInc,
              ),
              const SizedBox(width: 16),
              _buildMetricPicker("Reps", reps.toString(), onRepsDec, onRepsInc),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            text: exercise.sets.any((s) => !s.isCompleted)
                ? "Complete Set"
                : "All Sets Done",
            onPressed: exercise.sets.any((s) => !s.isCompleted)
                ? () {
                    final pending = exercise.sets
                        .where((s) => !s.isCompleted)
                        .toList();
                    final current = pending.first;
                    provider.completeSet(current.id!, weight, reps);
                    final isLast = pending.length == 1;
                    AppSnackbar.success(
                      context,
                      isLast
                          ? '${exercise.name} complete — great work!'
                          : 'Set ${current.setNumber} logged: '
                                '${weight.toStringAsFixed(1)}kg × $reps',
                      aboveNav: true,
                    );
                  }
                : () => AppSnackbar.info(
                    context,
                    'All sets for ${exercise.name} are already done.',
                    aboveNav: true,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPicker(
    String label,
    String value,
    VoidCallback onDec,
    VoidCallback onInc,
  ) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        borderRadius: 16,
        child: Column(
          children: [
            Text(label, style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onDec,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: onInc,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
