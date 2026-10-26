import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../utils/format.dart';
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
          Text(exercise.name, style: AppTextStyles.h3),
          if (exercise.muscleGroup.isNotEmpty)
            Text(
              exercise.muscleGroup,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetricPicker(
                "Weight",
                "${formatWeight(weight)} kg",
                onWeightDec,
                onWeightInc,
              ),
              const SizedBox(width: 12),
              _buildMetricPicker("Reps", reps.toString(), onRepsDec, onRepsInc),
            ],
          ),
          const SizedBox(height: 18),
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
                                '${formatWeight(weight)} kg × $reps',
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.fieldLabel),
            const SizedBox(height: 4),
            Row(
              children: [
                _stepButton(
                  Icons.remove_rounded,
                  onDec,
                  AppColors.textSecondary,
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _stepButton(Icons.add_rounded, onInc, AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap, Color color) =>
      IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 22),
      );
}
