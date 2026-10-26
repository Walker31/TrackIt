import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/responsive.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:go_router/go_router.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import '../models/workouts.dart';
import '../providers/app_providers.dart';
import '../widgets/workouts/session_summary_card.dart';
import '../widgets/workouts/routine_selector.dart';
import '../widgets/workouts/exercise_grid.dart';
import '../widgets/workouts/active_exercise_tracker.dart';
import '../widgets/workouts/rest_timer_overlay.dart';
import '../widgets/app_button.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_container.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  int? _selectedExerciseIndex = 0;
  double _weight = 80;
  int _reps = 10;

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(workoutProviderProvider);
    final workout = provider.todayWorkout;

    if (workout == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'Training',
                  trailing: IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: Icon(
                      Icons.settings_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    Responsive.pageBottomPadding(context, hasFab: true),
                  ),
                  child: ResponsiveColumns(
                    gap: 40,
                    left: [
                      FadeSlideIn(child: SessionSummaryCard(workout: workout)),
                      const SizedBox(height: 32),
                      FadeSlideIn(
                        index: 1,
                        child: RoutineSelector(
                          provider: provider,
                          onCreateRoutine: () =>
                              _showCreateRoutineSheet(context),
                        ),
                      ),
                    ],
                    right: [
                      const FadeSlideIn(
                        index: 2,
                        child: SectionHeader(
                          title: "Active Exercises",
                          subtitle: "Workout Progress",
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        index: 3,
                        child: ExerciseGrid(
                          workout: workout,
                          selectedIndex: _selectedExerciseIndex ?? 0,
                          onSelect: (index) =>
                              _onExerciseSelected(workout, index),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (workout.exercises.isNotEmpty) ...[
                        // Re-run the entrance when switching exercises.
                        FadeSlideIn(
                          key: ValueKey(_selectedExerciseIndex ?? 0),
                          child: ActiveExerciseTracker(
                            exercise:
                                workout.exercises[_selectedExerciseIndex ?? 0],
                            provider: provider,
                            weight: _weight,
                            reps: _reps,
                            onWeightDec: () => setState(() => _weight -= 2.5),
                            onWeightInc: () => setState(() => _weight += 2.5),
                            onRepsDec: () =>
                                setState(() => _reps > 0 ? _reps-- : 0),
                            onRepsInc: () => setState(() => _reps++),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSetHistory(workout),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: provider.isTimerRunning
                  ? RestTimerOverlay(provider: provider)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: Responsive.navInset(context)),
        child: FloatingActionButton(
          onPressed: () => _showAddExerciseSheet(context),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _onExerciseSelected(Workout workout, int index) {
    setState(() {
      _selectedExerciseIndex = index;
      final exercise = workout.exercises[index];
      final nextSet =
          exercise.sets.where((s) => !s.isCompleted).firstOrNull ??
          exercise.sets.lastOrNull;
      if (nextSet != null && nextSet.weight > 0) {
        _weight = nextSet.weight;
        _reps = nextSet.reps;
      }
    });
  }

  Widget _buildSetHistory(Workout workout) {
    final exercise = workout.exercises[_selectedExerciseIndex ?? 0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SET HISTORY", style: AppTextStyles.label),
        const SizedBox(height: 12),
        ...exercise.sets.map(
          (set) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: set.isCompleted
                        ? AppColors.surfaceVariant
                        : AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${set.setNumber}",
                      style: AppTextStyles.bodySm,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "${set.weight}kg x ${set.reps}",
                  style: AppTextStyles.bodyMd,
                ),
                const Spacer(),
                Icon(
                  set.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: set.isCompleted
                      ? AppColors.secondary
                      : AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddExerciseSheet(BuildContext context) {
    final provider = ref.read(workoutProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExerciseSheet(
        onAdd: (exercise) {
          provider.addExercise(exercise);
          AppSnackbar.success(
            this.context,
            '${exercise.name} added to today\'s workout.',
            aboveNav: true,
          );
        },
      ),
    );
  }

  void _showCreateRoutineSheet(BuildContext context) {
    final provider = ref.read(workoutProviderProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateRoutineSheet(
        onSave: (routine) {
          provider.addRoutine(routine);
          AppSnackbar.success(
            this.context,
            'Routine "${routine.name}" created.',
            aboveNav: true,
          );
        },
      ),
    );
  }
}

class _CreateRoutineSheet extends StatefulWidget {
  final Function(Routine) onSave;
  const _CreateRoutineSheet({required this.onSave});

  @override
  State<_CreateRoutineSheet> createState() => _CreateRoutineSheetState();
}

class _CreateRoutineSheetState extends State<_CreateRoutineSheet> {
  final _nameController = TextEditingController();
  WorkoutType _selectedType = WorkoutType.push;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create Routine", style: AppTextStyles.h2),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: "Routine Name (e.g. Upper Body A)",
            ),
          ),
          const SizedBox(height: 24),
          Text("Workout Type", style: AppTextStyles.label),
          const SizedBox(height: 12),
          Row(
            children: WorkoutType.values.map((type) {
              final isSelected = _selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selectedType = type),
                  selectedColor: type.color.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? type.color : AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          AppButton(
            text: "Create Routine",
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                widget.onSave(
                  Routine(
                    name: _nameController.text,
                    type: _selectedType,
                    exercises: [],
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  final Function(Exercise) onAdd;
  const _AddExerciseSheet({required this.onAdd});

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController();
  int _setsCount = 3;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("New Exercise", style: AppTextStyles.h2),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: "Exercise Name (e.g. Bench Press)",
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _muscleController,
            decoration: const InputDecoration(
              hintText: "Muscle Group (e.g. Chest)",
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sets", style: AppTextStyles.bodyLg),
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _setsCount > 1 ? _setsCount-- : 1),
                    icon: const Icon(Icons.remove),
                  ),
                  Text("$_setsCount", style: AppTextStyles.h3),
                  IconButton(
                    onPressed: () => setState(() => _setsCount++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          AppButton(
            text: "Add to Workout",
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                final exercise = Exercise(
                  workoutId: 0,
                  name: _nameController.text,
                  muscleGroup: _muscleController.text,
                  sets: List.generate(
                    _setsCount,
                    (i) => SetData(
                      exerciseId: 0,
                      setNumber: i + 1,
                      weight: 0,
                      reps: 0,
                    ),
                  ),
                );
                widget.onAdd(exercise);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
