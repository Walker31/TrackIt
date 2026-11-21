import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workouts.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';
import '../services/prefs_service.dart';
import '../services/app_mode_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';
import 'app_sheet.dart';
import 'app_snackbar.dart';
import 'glass_container.dart';

/// A ready-made training split.
class StarterSplit {
  final String name;
  final String description;
  final List<(String name, WorkoutType type, List<String> exercises)> days;
  const StarterSplit(this.name, this.description, this.days);

  List<Routine> toRoutines() => [
    for (final (name, type, exercises) in days)
      Routine(
        name: name,
        type: type,
        exercises: [
          for (final e in exercises)
            RoutineExercise(
              routineId: 0,
              name: e,
              muscleGroup: muscleGroupFor(e) ?? '',
              setsCount: 3,
            ),
        ],
      ),
  ];
}

const starterSplits = [
  StarterSplit('Push / Pull / Legs', '3 days, a classic for building muscle', [
    (
      'Push day',
      WorkoutType.push,
      [
        'Bench Press',
        'Overhead Press',
        'Incline Dumbbell Press',
        'Lateral Raise',
        'Tricep Pushdown',
      ],
    ),
    (
      'Pull day',
      WorkoutType.pull,
      ['Pull-up', 'Barbell Row', 'Lat Pulldown', 'Face Pull', 'Barbell Curl'],
    ),
    (
      'Leg day',
      WorkoutType.legs,
      [
        'Squat',
        'Romanian Deadlift',
        'Leg Press',
        'Leg Curl',
        'Standing Calf Raise',
      ],
    ),
  ]),
  StarterSplit('Upper / Lower', '2 days, easy to fit into a week', [
    (
      'Upper body',
      WorkoutType.push,
      [
        'Bench Press',
        'Barbell Row',
        'Overhead Press',
        'Lat Pulldown',
        'Dumbbell Curl',
        'Tricep Pushdown',
      ],
    ),
    (
      'Lower body',
      WorkoutType.legs,
      [
        'Squat',
        'Romanian Deadlift',
        'Leg Press',
        'Leg Curl',
        'Standing Calf Raise',
      ],
    ),
  ]),
  StarterSplit('Full body', 'One session, everything, 2–3 times a week', [
    (
      'Full body',
      WorkoutType.legs,
      [
        'Squat',
        'Bench Press',
        'Barbell Row',
        'Overhead Press',
        'Romanian Deadlift',
        'Plank',
      ],
    ),
  ]),
];

/// Shows the first-run setup once, on a device with no data yet. Devices
/// that already have data are marked as set up without asking.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key});

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  static const key = 'onboarded';
  static bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final prefs = PrefsService();
    if (await prefs.getBool(key, false)) return;
    // A signed-in account may have data still to download: decide after
    // the first sync has brought it down.
    if (AppModeService.isServer && await SyncService.lastSyncedAt() == null) {
      return;
    }
    final db = await DatabaseService().getDatabase();
    final rows = await db.rawQuery(
      'SELECT (SELECT COUNT(*) FROM expenses) + (SELECT COUNT(*) FROM workouts)'
      ' + (SELECT COUNT(*) FROM routines) AS n',
    );
    await prefs.setBool(key, true);
    if (((rows.first['n'] as int?) ?? 0) > 0 || !mounted) return;
    await showAppSheet<void>(
      context: context,
      builder: (_) => const OnboardingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class OnboardingSheet extends ConsumerStatefulWidget {
  const OnboardingSheet({super.key});

  @override
  ConsumerState<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends ConsumerState<OnboardingSheet> {
  final _budget = TextEditingController();
  StarterSplit? _split = starterSplits.first;
  bool _saving = false;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final budget = double.tryParse(_budget.text);
    final expenses = ref.read(expenseProviderProvider);
    final workouts = ref.read(workoutProviderProvider);
    if (budget != null && budget > 0) await expenses.updateBudget(budget);
    final split = _split;
    if (split != null) {
      for (final r in split.toRoutines()) {
        await workouts.addRoutine(r);
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
    AppSnackbar.success(
      context,
      split == null
          ? "You're set. Add your first expense with +."
          : "You're set. Your ${split.name} routines are in the Workout tab.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      sheet: true,
      borderRadius: 24,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome to TrackIt 👋', style: AppTextStyles.h2),
            const SizedBox(height: 6),
            Text(
              'Two quick choices and Today has something to show. You can '
              'change both later.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text('Monthly budget', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                prefixText: '₹ ',
                hintText: 'e.g. 30000',
              ),
            ),
            const SizedBox(height: 24),
            Text('Training plan', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            RadioGroup<StarterSplit?>(
              groupValue: _split,
              onChanged: (v) => setState(() => _split = v),
              child: Column(
                children: [
                  for (final s in starterSplits)
                    RadioListTile<StarterSplit?>(
                      contentPadding: EdgeInsets.zero,
                      value: s,
                      title: Text(s.name),
                      subtitle: Text(s.description),
                    ),
                  const RadioListTile<StarterSplit?>(
                    contentPadding: EdgeInsets.zero,
                    value: null,
                    title: Text("I'll set it up myself"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Get started',
              isLoading: _saving,
              onPressed: _finish,
            ),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
