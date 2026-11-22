import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/responsive.dart';
import '../widgets/animated/fade_slide_in.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/page_header.dart';
import '../widgets/section_header.dart';
import '../models/workouts.dart';
import '../providers/app_providers.dart';
import '../providers/workout_provider.dart';
import '../services/progress_service.dart';
import '../widgets/workouts/session_summary_card.dart';
import '../widgets/workouts/routine_selector.dart';
import '../widgets/workouts/exercise_grid.dart';
import '../widgets/workouts/active_exercise_tracker.dart';
import '../widgets/workouts/rest_timer_overlay.dart';
import '../widgets/app_button.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_container.dart';
import '../utils/format.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  int? _selectedExerciseIndex = 0;
  double _weight = 20;
  int _reps = 8;
  int _streak = 0;

  /// The exercise whose numbers are loaded into the pickers, so they're
  /// seeded once per exercise rather than reset on every rebuild.
  int? _seededExerciseId;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final s = await ProgressService().streak();
    if (mounted && s != _streak) setState(() => _streak = s);
  }

  @override
  Widget build(BuildContext context) {
    final wide = !WindowSize.of(context).usesBottomNav;
    final provider = ref.watch(workoutProviderProvider);
    final workout = provider.todayWorkout;
    ref.listen(workoutProviderProvider, (_, _) => _loadStreak());

    if (workout == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final index = (_selectedExerciseIndex ?? 0).clamp(
      0,
      workout.exercises.isEmpty ? 0 : workout.exercises.length - 1,
    );
    if (workout.exercises.isNotEmpty) {
      final current = workout.exercises[index];
      if (current.id != null && current.id != _seededExerciseId) {
        _seededExerciseId = current.id;
        _seedFrom(current);
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'Workout',
                  overline: _streak > 1 ? '$_streak-day streak' : null,
                  actions: [
                    IconButton(
                      tooltip: 'Workout history',
                      onPressed: () => context.push('/history'),
                      icon: Icon(
                        Icons.history_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Personal records',
                      onPressed: () => context.push('/records'),
                      icon: Icon(
                        Icons.emoji_events_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (wide)
                      HeaderAddButton(
                        label: 'Add exercise',
                        onPressed: () => _showAddExerciseSheet(context),
                      ),
                  ],
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
                      if (workout.getTotalSets() > 0 &&
                          workout.getTotalCompletedSets() ==
                              workout.getTotalSets() &&
                          workout.id != null) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          text: 'See workout summary',
                          icon: Icons.celebration_outlined,
                          isPrimary: false,
                          onPressed: () =>
                              context.push('/history/${workout.id}?done=1'),
                        ),
                      ],
                      const SizedBox(height: 28),
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
                        child: SectionHeader(title: "Exercises"),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        index: 3,
                        child: ExerciseGrid(
                          workout: workout,
                          selectedIndex: index,
                          onSelect: (i) => _onExerciseSelected(workout, i),
                          onOptions: (i) =>
                              _exerciseOptions(workout.exercises[i]),
                          onAdd: () => _showAddExerciseSheet(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (workout.exercises.isNotEmpty) ...[
                        // Re-run the entrance when switching exercises.
                        FadeSlideIn(
                          key: ValueKey(index),
                          child: ActiveExerciseTracker(
                            exercise: workout.exercises[index],
                            provider: provider,
                            weight: _weight,
                            reps: _reps,
                            // Nothing planned or done yet today: start
                            // from last time's numbers.
                            prefillFromLastTime: workout.exercises[index].sets
                                .every((s) => !s.isCompleted && s.weight <= 0),
                            onChanged: (w, r) => setState(() {
                              _weight = w;
                              _reps = r;
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SetList(
                          exercise: workout.exercises[index],
                          provider: provider,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
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
      floatingActionButton: wide
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: Responsive.navInset(context)),
              child: FloatingActionButton(
                onPressed: () => _showAddExerciseSheet(context),
                tooltip: 'Add exercise',
                child: const Icon(Icons.add),
              ),
            ),
    );
  }

  void _onExerciseSelected(Workout workout, int index) {
    setState(() {
      _selectedExerciseIndex = index;
      final exercise = workout.exercises[index];
      _seededExerciseId = exercise.id;
      _seedFrom(exercise);
    });
  }

  /// Loads the next planned set's numbers, or the last done set's.
  void _seedFrom(Exercise exercise) {
    final nextSet =
        exercise.sets.where((s) => !s.isCompleted).firstOrNull ??
        exercise.sets.lastOrNull;
    final lastDone = exercise.sets.where((s) => s.isCompleted).lastOrNull;
    final source = nextSet != null && nextSet.weight > 0 ? nextSet : lastDone;
    if (source != null && (source.weight > 0 || source.reps > 0)) {
      _weight = source.weight;
      _reps = source.reps;
    }
  }

  Future<void> _exerciseOptions(Exercise exercise) async {
    final provider = ref.read(workoutProviderProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart_rounded),
              title: const Text('See progress'),
              onTap: () => Navigator.pop(context, 'progress'),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Add a set'),
              onTap: () => Navigator.pop(context, 'add'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.expense),
              title: Text(
                'Remove ${exercise.name}',
                style: TextStyle(color: AppColors.expense),
              ),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'progress':
        context.push(
          '/exercise?name=${Uri.encodeQueryComponent(exercise.name)}',
        );
      case 'add':
        await provider.addSetTo(exercise);
      case 'remove':
        await provider.deleteExercise(exercise.id!);
        if (!mounted) return;
        setState(() => _selectedExerciseIndex = 0);
        AppSnackbar.info(
          context,
          '${exercise.name} removed.',
          actionLabel: 'Undo',
          onAction: () => provider.restoreExercise(exercise),
        );
    }
  }

  Future<void> _showAddExerciseSheet(BuildContext context) async {
    final provider = ref.read(workoutProviderProvider);
    final known = await ProgressService().allRecords();
    if (!mounted) return;
    showAppSheet(
      context: this.context,
      builder: (context) => AddExerciseSheet(
        known: [for (final r in known) LibraryExercise(r.name, r.muscleGroup)],
        onAdd: (exercise) async {
          await provider.addExercise(exercise);
          if (!mounted) return;
          final count = provider.todayWorkout?.exercises.length ?? 1;
          _onExerciseSelected(provider.todayWorkout!, count - 1);
          AppSnackbar.success(
            this.context,
            '${exercise.name} added to today\'s workout.',
          );
        },
      ),
    );
  }

  void _showCreateRoutineSheet(BuildContext context) {
    final provider = ref.read(workoutProviderProvider);
    showAppSheet(
      context: context,
      builder: (context) => _CreateRoutineSheet(
        today: provider.todayWorkout,
        onSave: (routine) {
          provider.addRoutine(routine);
          AppSnackbar.success(
            this.context,
            'Routine "${routine.name}" created.',
          );
        },
      ),
    );
  }
}

/// Today's sets for one exercise. Tap a done set to undo it, swipe to
/// delete, or add another.
class _SetList extends StatelessWidget {
  final Exercise exercise;
  final WorkoutProvider provider;

  const _SetList({required this.exercise, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text("Sets", style: AppTextStyles.fieldLabel)),
            TextButton.icon(
              onPressed: () => _pickRest(context),
              icon: const Icon(Icons.timer_outlined, size: 16),
              label: Text('Rest ${formatDuration(provider.defaultRest)}'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final set in exercise.sets)
          Dismissible(
            key: ValueKey('set-${set.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: AppColors.expense.withValues(alpha: 0.12),
              child: Icon(Icons.delete_outline, color: AppColors.expense),
            ),
            onDismissed: (_) async {
              await provider.deleteSet(set.id!);
              if (!context.mounted) return;
              AppSnackbar.info(
                context,
                'Set ${set.setNumber} deleted.',
                actionLabel: 'Undo',
                onAction: () => provider.addSet(
                  SetData(
                    exerciseId: exercise.id!,
                    setNumber: exercise.sets.length,
                    weight: set.weight,
                    reps: set.reps,
                    isCompleted: set.isCompleted,
                  ),
                ),
              );
            },
            child: _SetRow(
              set: set,
              onTap: set.isCompleted
                  ? () {
                      provider.uncompleteSet(set.id!);
                      AppSnackbar.info(
                        context,
                        'Set ${set.setNumber} marked as not done.',
                      );
                    }
                  : null,
            ),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => provider.addSetTo(exercise),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add set'),
        ),
      ],
    );
  }

  Future<void> _pickRest(BuildContext context) async {
    const options = [30, 45, 60, 90, 120, 150, 180, 240, 300];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rest between sets', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in options)
                    ChoiceChip(
                      label: Text(formatDuration(s)),
                      selected: s == provider.defaultRest,
                      onSelected: (_) => Navigator.pop(context, s),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) provider.setDefaultRest(picked);
  }
}

class _SetRow extends StatelessWidget {
  final SetData set;
  final VoidCallback? onTap;

  const _SetRow({required this.set, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = set.isCompleted || set.reps > 0
        ? "${formatWeight(set.weight)} kg × ${set.reps}"
        : "Not done yet";
    return Semantics(
      label:
          'Set ${set.setNumber}, $label, ${set.isCompleted ? 'done' : 'not done'}',
      hint: onTap != null ? 'Tap to mark as not done. Swipe to delete.' : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: set.isCompleted
                      ? AppColors.secondary.withValues(alpha: 0.12)
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${set.setNumber}",
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: set.isCompleted
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                  color: set.isCompleted
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
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
    );
  }
}

class _CreateRoutineSheet extends StatefulWidget {
  final Function(Routine) onSave;
  final Workout? today;
  const _CreateRoutineSheet({required this.onSave, this.today});

  @override
  State<_CreateRoutineSheet> createState() => _CreateRoutineSheetState();
}

class _CreateRoutineSheetState extends State<_CreateRoutineSheet> {
  final _nameController = TextEditingController();
  late WorkoutType _selectedType = widget.today?.type ?? WorkoutType.push;
  late bool _includeToday = (widget.today?.exercises.isNotEmpty ?? false);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayExercises = widget.today?.exercises ?? const <Exercise>[];
    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 24,
      sheet: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("New routine", style: AppTextStyles.h2),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: "Routine name (e.g. Upper Body A)",
            ),
          ),
          const SizedBox(height: 24),
          Text("Workout type", style: AppTextStyles.fieldLabel),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WorkoutType.values.map((type) {
              final isSelected = _selectedType == type;
              return ChoiceChip(
                avatar: Icon(
                  type.icon,
                  size: 16,
                  color: isSelected ? type.color : AppColors.textSecondary,
                ),
                label: Text(type.displayName),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedType = type),
                selectedColor: type.color.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? type.color : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
          if (todayExercises.isNotEmpty) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeToday,
              onChanged: (v) => setState(() => _includeToday = v),
              title: const Text("Include today's exercises"),
              subtitle: Text(
                todayExercises.map((e) => e.name).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            text: "Create routine",
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              widget.onSave(
                Routine(
                  name: name,
                  type: _selectedType,
                  exercises: [
                    if (_includeToday)
                      for (final e in todayExercises)
                        RoutineExercise(
                          routineId: 0,
                          name: e.name,
                          muscleGroup: e.muscleGroup,
                          setsCount: e.sets.isEmpty ? 3 : e.sets.length,
                        ),
                  ],
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Pick an exercise from the library (or ones you've done before), or
/// type a new one.
class AddExerciseSheet extends StatefulWidget {
  final Function(Exercise) onAdd;
  final List<LibraryExercise> known;
  const AddExerciseSheet({
    super.key,
    required this.onAdd,
    this.known = const [],
  });

  @override
  State<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<AddExerciseSheet> {
  final _nameController = TextEditingController();
  String _muscle = '';
  int _setsCount = 3;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _pick(LibraryExercise e) {
    setState(() {
      _nameController.text = e.name;
      _nameController.selection = TextSelection.collapsed(
        offset: e.name.length,
      );
      _muscle = e.muscleGroup;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final muscle = _muscle.isNotEmpty ? _muscle : (muscleGroupFor(name) ?? '');
    widget.onAdd(
      Exercise(
        workoutId: 0,
        name: name,
        muscleGroup: muscle,
        sets: List.generate(
          _setsCount,
          (i) => SetData(exerciseId: 0, setNumber: i + 1, weight: 0, reps: 0),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final query = _nameController.text;
    final matches = searchExercises(query, extra: widget.known, limit: 8);
    final exact = matches.any(
      (e) => e.name.toLowerCase() == query.trim().toLowerCase(),
    );
    return GlassContainer(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      borderRadius: 24,
      sheet: true,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New exercise", style: AppTextStyles.h2),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (v) => setState(() {
                final known = muscleGroupFor(v);
                if (known != null) _muscle = known;
              }),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: "Search or type a name (e.g. Bench Press)",
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (!exact && matches.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in matches)
                    ActionChip(
                      label: Text(e.name),
                      tooltip: e.muscleGroup.isEmpty ? null : e.muscleGroup,
                      onPressed: () => _pick(e),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text("Muscle group", style: AppTextStyles.fieldLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in muscleGroups)
                  ChoiceChip(
                    label: Text(m),
                    selected: _muscle == m,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (on) => setState(() => _muscle = on ? m : ''),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Sets", style: AppTextStyles.bodyLg),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Fewer sets',
                      onPressed: () =>
                          setState(() => _setsCount > 1 ? _setsCount-- : 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text("$_setsCount", style: AppTextStyles.h3),
                    IconButton(
                      tooltip: 'More sets',
                      onPressed: () => setState(() => _setsCount++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppButton(
              text: "Add to workout",
              onPressed: query.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
