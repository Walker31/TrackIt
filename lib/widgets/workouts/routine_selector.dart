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
          title: "My Routines",
          subtitle: "Quick Start",
          action: IconButton(
            onPressed: onCreateRoutine,
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (provider.routines.isEmpty)
          const Text("No routines saved yet.", style: AppTextStyles.bodySm)
        else
          SizedBox(
            height: 80,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      borderRadius: 16,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            routine.name,
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${routine.exercises.length} Exercises",
                            style: AppTextStyles.label,
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
