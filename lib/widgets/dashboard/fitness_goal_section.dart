import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../empty_state.dart';
import '../section_header.dart';
import '../../models/workouts.dart';
import '../../providers/workout_provider.dart';
import '../animated/fade_slide_in.dart';
import '../../services/progress_service.dart';

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
            child: const Text("View all"),
          ),
        ),
        const SizedBox(height: 8),
        if (firstLoad)
          const SizedBox(height: 80)
        else if (workout == null || workout.exercises.isEmpty)
          _QuickStart(provider: provider, onOpen: onViewAll)
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
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing logged today: one tap to start a routine or repeat last time.
class _QuickStart extends StatefulWidget {
  final WorkoutProvider provider;
  final VoidCallback onOpen;
  const _QuickStart({required this.provider, required this.onOpen});

  @override
  State<_QuickStart> createState() => _QuickStartState();
}

class _QuickStartState extends State<_QuickStart> {
  late final Future<(List<Workout>, int)> _data = (
    ProgressService().history(limit: 1),
    ProgressService().streak(),
  ).wait;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      widget.onOpen();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routines = widget.provider.routines;
    return FutureBuilder<(List<Workout>, int)>(
      future: _data,
      builder: (context, snap) {
        final last = snap.data?.$1.firstOrNull;
        final streak = snap.data?.$2 ?? 0;
        if (routines.isEmpty && last == null) {
          return const EmptyState(
            card: true,
            compact: true,
            icon: Icons.fitness_center_rounded,
            title: 'No workout yet',
            message: 'Add exercises in the Workout tab to track sets.',
          );
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streak > 0
                    ? '🔥 $streak-day streak. Keep it going?'
                    : 'Ready when you are.',
                style: AppTextStyles.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (last != null)
                    ActionChip(
                      avatar: const Icon(Icons.replay_rounded, size: 18),
                      label: Text('Repeat ${last.type.displayName}'),
                      onPressed: _busy
                          ? null
                          : () =>
                                _run(() => widget.provider.repeatWorkout(last)),
                    ),
                  for (final r in routines.take(3))
                    ActionChip(
                      avatar: Icon(r.type.icon, size: 18),
                      label: Text('Start ${r.name}'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => widget.provider.startWorkoutFromRoutine(r),
                            ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
