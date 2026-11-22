import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../layout.dart' show AppTab;
import '../models/workouts.dart';
import '../providers/app_providers.dart';
import '../services/progress_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/format.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/empty_state.dart';

/// Keeps page content readable on wide windows.
Widget _constrained(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: child,
  ),
);

// ---------------------------------------------------------------------------
// Workout history

class WorkoutHistoryPage extends ConsumerStatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  ConsumerState<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends ConsumerState<WorkoutHistoryPage> {
  static const _page = 30;
  final _workouts = <Workout>[];
  bool _loading = true;
  bool _more = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _workouts.clear();
      _more = true;
    }
    setState(() => _loading = true);
    final next = await ProgressService().history(
      limit: _page,
      offset: _workouts.length,
    );
    if (!mounted) return;
    setState(() {
      _workouts.addAll(next);
      _more = next.length == _page;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workoutProviderProvider, (_, _) => _load(reset: true));
    final groups = <String, List<Workout>>{};
    for (final w in _workouts) {
      groups
          .putIfAbsent(DateFormat('MMMM yyyy').format(w.timestamp), () => [])
          .add(w);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: _workouts.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _workouts.isEmpty
          ? _constrained(
              Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyState(
                  card: true,
                  icon: Icons.history_rounded,
                  title: 'No workouts yet',
                  message:
                      'Finished workouts show up here, so you can look back '
                      'or repeat one.',
                  actionLabel: 'Start a workout',
                  onAction: () => context.go(AppTab.workout.path),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  for (final entry in groups.entries)
                    _constrained(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          for (final w in entry.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: WorkoutTile(
                                workout: w,
                                onTap: () => context.push('/history/${w.id}'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_more)
                    Center(
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _load,
                              child: const Text('Load older workouts'),
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}

class WorkoutTile extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const WorkoutTile({super.key, required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final names = w.exercises.map((e) => e.name).join(' · ');
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: w.type.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(w.type.icon, color: w.type.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('EEE d MMM').format(w.timestamp)} · '
                      '${w.type.displayName}',
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      names,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatWeight(w.getTotalSessionVolume())} kg',
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${w.getTotalCompletedSets()} sets',
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
  }
}

// ---------------------------------------------------------------------------
// One workout

class WorkoutDetailPage extends ConsumerStatefulWidget {
  final int workoutId;

  /// Opened right after finishing: show the celebration header.
  final bool justFinished;

  const WorkoutDetailPage({
    super.key,
    required this.workoutId,
    this.justFinished = false,
  });

  @override
  ConsumerState<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends ConsumerState<WorkoutDetailPage> {
  late Future<_Detail?> _detail = _load();

  Future<_Detail?> _load() async {
    final service = ProgressService();
    final w = await service.workout(widget.workoutId);
    if (w == null) return null;
    // Records set in this workout, against everything before it.
    final records = <String>[];
    for (final ex in w.exercises) {
      final done = ex.sets.where((s) => s.isCompleted).toList();
      if (done.isEmpty) continue;
      final earlier = (await service.sessionsFor(
        ex.name,
        excludeWorkoutId: w.id,
      )).where((s) => s.date.isBefore(w.timestamp)).toList();
      final prev = ExerciseRecords.from(ex.name, '', earlier);
      final best = done.reduce(
        (a, b) =>
            estimatedOneRepMax(b.weight, b.reps) >
                estimatedOneRepMax(a.weight, a.reps)
            ? b
            : a,
      );
      final heaviest = done.reduce((a, b) => b.weight > a.weight ? b : a);
      if (newRecords(
        LoggedSet(heaviest.weight, heaviest.reps),
        prev,
      ).contains(RecordKind.weight)) {
        records.add(
          '${ex.name}: heaviest ever, '
          '${formatWeight(heaviest.weight)} kg × ${heaviest.reps}',
        );
      } else if (newRecords(
        LoggedSet(best.weight, best.reps),
        prev,
      ).isNotEmpty) {
        records.add(
          '${ex.name}: best estimated max, '
          '${formatWeight(estimatedOneRepMax(best.weight, best.reps))} kg',
        );
      }
    }
    return _Detail(w, records);
  }

  Future<void> _repeat(Workout w) async {
    await ref.read(workoutProviderProvider).repeatWorkout(w);
    if (!mounted) return;
    AppSnackbar.success(context, "Added to today's workout.");
    context.go(AppTab.workout.path);
  }

  Future<void> _delete(Workout w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this workout?'),
        content: const Text(
          'Its exercises and sets are removed from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(workoutProviderProvider).deleteWorkout(w.id!);
    if (!mounted) return;
    AppSnackbar.info(context, 'Workout deleted.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Detail?>(
      future: _detail,
      builder: (context, snap) {
        final d = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              d == null
                  ? 'Workout'
                  : DateFormat('EEEE d MMM').format(d.workout.timestamp),
            ),
            actions: [
              if (d != null)
                IconButton(
                  tooltip: 'Delete workout',
                  onPressed: () => _delete(d.workout),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : d == null
              ? const Center(child: Text('This workout no longer exists.'))
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _detail = _load());
                    await _detail;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _constrained(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.justFinished)
                              _FinishedBanner(records: d.records.length),
                            _StatsRow(workout: d.workout),
                            if (d.records.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.emoji_events_rounded,
                                          color: AppColors.accent,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'New records',
                                          style: AppTextStyles.h3,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    for (final r in d.records)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          r,
                                          style: AppTextStyles.bodyMd,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            for (final ex in d.workout.exercises)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ExerciseCard(exercise: ex),
                              ),
                            const SizedBox(height: 8),
                            AppButton(
                              text: 'Do this workout again',
                              icon: Icons.replay_rounded,
                              onPressed: () => _repeat(d.workout),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Detail {
  final Workout workout;
  final List<String> records;
  _Detail(this.workout, this.records);
}

class _FinishedBanner extends StatelessWidget {
  final int records;
  const _FinishedBanner({required this.records});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        gradient: AppColors.brandGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Workout complete',
              style: AppTextStyles.h2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              records == 0
                  ? 'Nice work. Every session counts.'
                  : records == 1
                  ? 'You set a new record today!'
                  : 'You set $records new records today!',
              style: AppTextStyles.bodyMd.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Workout workout;
  const _StatsRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.h3),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        stat('${formatWeight(workout.getTotalSessionVolume())} kg', 'Volume'),
        const SizedBox(width: 10),
        stat('${workout.getTotalCompletedSets()}', 'Sets done'),
        const SizedBox(width: 10),
        stat('${workout.exercises.length}', 'Exercises'),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          '/exercise?name=${Uri.encodeQueryComponent(exercise.name)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(exercise.name, style: AppTextStyles.h3)),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              if (exercise.muscleGroup.isNotEmpty)
                Text(
                  exercise.muscleGroup,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 8),
              for (final s in exercise.sets)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          'Set ${s.setNumber}',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        s.isCompleted
                            ? '${formatWeight(s.weight)} kg × ${s.reps}'
                            : 'Not done',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: s.isCompleted
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Personal records

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _records = ProgressService().allRecords();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal records')),
      body: FutureBuilder<List<ExerciseRecords>>(
        future: _records,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final all = snap.data!;
          if (all.isEmpty) {
            return _constrained(
              Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyState(
                  card: true,
                  icon: Icons.emoji_events_outlined,
                  title: 'No records yet',
                  message: 'Complete a few sets and your bests appear here.',
                  actionLabel: 'Go to workout',
                  onAction: () => context.go(AppTab.workout.path),
                ),
              ),
            );
          }
          final q = _query.trim().toLowerCase();
          final shown = all
              .where(
                (r) =>
                    q.isEmpty ||
                    r.name.toLowerCase().contains(q) ||
                    r.muscleGroup.toLowerCase().contains(q),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _constrained(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search exercises',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final r in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecordTile(records: r),
                      ),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No exercise matches "$_query".',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final ExerciseRecords records;
  const _RecordTile({required this.records});

  @override
  Widget build(BuildContext context) {
    final r = records;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/exercise?name=${Uri.encodeQueryComponent(r.name)}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: AppTextStyles.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        if (r.muscleGroup.isNotEmpty) r.muscleGroup,
                        '${r.sessions} ${r.sessions == 1 ? 'session' : 'sessions'}',
                      ].join(' · '),
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    r.bestWeight > 0
                        ? '${formatWeight(r.bestWeight)} kg × ${r.repsAtBestWeight}'
                        : '${r.repsAtBestWeight} reps',
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (r.bestOneRepMax > 0)
                    Text(
                      'Est. max ${formatWeight(r.bestOneRepMax)} kg',
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
  }
}

// ---------------------------------------------------------------------------
// One exercise over time

enum _Metric { oneRepMax, topWeight, volume }

class ExerciseProgressPage extends StatefulWidget {
  final String name;
  const ExerciseProgressPage({super.key, required this.name});

  @override
  State<ExerciseProgressPage> createState() => _ExerciseProgressPageState();
}

class _ExerciseProgressPageState extends State<ExerciseProgressPage> {
  late final _sessions = ProgressService().sessionsFor(widget.name);
  _Metric _metric = _Metric.oneRepMax;

  double _value(ExerciseSession s) => switch (_metric) {
    _Metric.oneRepMax => s.bestOneRepMax,
    _Metric.topWeight => s.topSet.weight,
    _Metric.volume => s.volume,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<List<ExerciseSession>>(
        future: _sessions,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final sessions = snap.data!;
          if (sessions.isEmpty) {
            return _constrained(
              const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  card: true,
                  icon: Icons.show_chart_rounded,
                  title: 'Nothing logged yet',
                  message:
                      'Complete a set of this exercise to start tracking it.',
                ),
              ),
            );
          }
          final records = ExerciseRecords.from(widget.name, '', sessions)!;
          final chrono = sessions.reversed.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _constrained(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _Best(
                          label: 'Heaviest',
                          value:
                              '${formatWeight(records.bestWeight)} kg × ${records.repsAtBestWeight}',
                        ),
                        const SizedBox(width: 10),
                        _Best(
                          label: 'Est. max',
                          value: '${formatWeight(records.bestOneRepMax)} kg',
                        ),
                        const SizedBox(width: 10),
                        _Best(
                          label: 'Best volume',
                          value:
                              '${formatWeight(records.bestSessionVolume)} kg',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<_Metric>(
                      segments: const [
                        ButtonSegment(
                          value: _Metric.oneRepMax,
                          label: Text('Est. max'),
                        ),
                        ButtonSegment(
                          value: _Metric.topWeight,
                          label: Text('Top set'),
                        ),
                        ButtonSegment(
                          value: _Metric.volume,
                          label: Text('Volume'),
                        ),
                      ],
                      selected: {_metric},
                      onSelectionChanged: (s) =>
                          setState(() => _metric = s.first),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: SizedBox(
                        height: 220,
                        child: chrono.length < 2
                            ? Center(
                                child: Text(
                                  'Log this exercise once more to see a trend.',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : _ProgressChart(
                                points: [
                                  for (final s in chrono) (s.date, _value(s)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Sessions', style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    for (final s in sessions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 92,
                              child: Text(
                                DateFormat('d MMM yy').format(s.date),
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.sets
                                    .map(
                                      (x) =>
                                          '${formatWeight(x.weight)}×${x.reps}',
                                    )
                                    .join(', '),
                                style: AppTextStyles.bodyMd,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Best extends StatelessWidget {
  final String label;
  final String value;
  const _Best({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProgressChart extends StatelessWidget {
  final List<(DateTime, double)> points;
  const _ProgressChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.$2);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(1, double.infinity).toDouble();
    return Semantics(
      label:
          'Progress chart. From ${formatWeight(points.first.$2)} to '
          '${formatWeight(points.last.$2)} kg over ${points.length} sessions.',
      child: LineChart(
        LineChartData(
          minY: (minY - pad).clamp(0, double.infinity).toDouble(),
          maxY: maxY + pad,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.textTertiary.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) => Text(
                  formatWeight(v),
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (points.length / 4).ceilToDouble().clamp(1, 1e9),
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length || v != i.toDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('d MMM').format(points[i].$1),
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${DateFormat('d MMM').format(points[s.x.round()].$1)}\n'
                    '${formatWeight(s.y)} kg',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].$2),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.workout,
              barWidth: 3,
              dotData: FlDotData(show: points.length <= 20),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.workout.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
