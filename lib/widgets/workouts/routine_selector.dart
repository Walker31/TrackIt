import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../section_header.dart';
import '../glass_container.dart';
import '../confirm_dialog.dart';
import '../../models/workouts.dart';
import '../../providers/workout_provider.dart';

class RoutineSelector extends StatelessWidget {
  final WorkoutProvider provider;
  final VoidCallback onCreateRoutine;

  const RoutineSelector({
    super.key,
    required this.provider,
    required this.onCreateRoutine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Routines",
          action: TextButton.icon(
            onPressed: onCreateRoutine,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New'),
          ),
        ),
        const SizedBox(height: 8),
        if (provider.routines.isEmpty)
          Text(
            "Save a routine to start a workout with one tap.",
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: provider.routines.length,
              itemBuilder: (context, index) {
                final routine = provider.routines[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => provider.startWorkoutFromRoutine(routine),
                    onLongPress: () => _confirmDelete(context, routine),
                    borderRadius: BorderRadius.circular(16),
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      borderRadius: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            routine.type.icon,
                            size: 20,
                            color: routine.type.color,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routine.name,
                                style: AppTextStyles.bodyMd.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${routine.exercises.length} '
                                'exercise${routine.exercises.length == 1 ? '' : 's'}',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Routine routine) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete routine?',
      message: '"${routine.name}" will be removed. Past workouts are kept.',
    );
    if (confirmed && routine.id != null) {
      await provider.deleteRoutine(routine.id!);
    }
  }
}
