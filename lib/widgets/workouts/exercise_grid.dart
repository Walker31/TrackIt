import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../empty_state.dart';
import '../../models/workouts.dart';

class ExerciseGrid extends StatelessWidget {
  final Workout workout;
  final int selectedIndex;
  final Function(int) onSelect;

  /// Opens the add-exercise sheet (offered when the list is empty).
  final VoidCallback? onAdd;

  const ExerciseGrid({
    super.key,
    required this.workout,
    required this.selectedIndex,
    required this.onSelect,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (workout.exercises.isEmpty) {
      return EmptyState(
        card: true,
        icon: Icons.fitness_center_rounded,
        title: 'No exercises yet',
        message: 'Add one, or start from a routine above.',
        actionLabel: 'Add exercise',
        onAction: onAdd,
      );
    }

    final hairline = AppColors.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: workout.exercises.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final exercise = workout.exercises[index];
          final isSelected = selectedIndex == index;
          final done = exercise.getCompletedSetsCount();
          final total = exercise.sets.length;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 132,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.brand : hairline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done == total && total > 0
                        ? 'All $total sets done'
                        : '$done of $total sets',
                    style: AppTextStyles.bodySm.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
