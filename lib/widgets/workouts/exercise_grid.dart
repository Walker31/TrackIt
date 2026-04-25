import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../models/workouts.dart';

class ExerciseGrid extends StatelessWidget {
  final Workout workout;
  final int selectedIndex;
  final Function(int) onSelect;

  const ExerciseGrid({
    super.key,
    required this.workout,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (workout.exercises.isEmpty) {
      return AppCard(
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.fitness_center, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text("No exercises added yet.", style: AppTextStyles.bodyLg),
              const SizedBox(height: 8),
              const Text("Tap the + button to start tracking.", style: AppTextStyles.bodySm),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: workout.exercises.length,
        itemBuilder: (context, index) {
          final exercise = workout.exercises[index];
          final isSelected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(exercise.name, style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("${exercise.getCompletedSetsCount()}/${exercise.sets.length}", style: AppTextStyles.bodySm.copyWith(
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
