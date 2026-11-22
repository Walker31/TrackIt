import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../app_card.dart';
import '../../utils/format.dart';
import '../app_button.dart';
import '../app_snackbar.dart';
import '../../models/workouts.dart';
import '../../providers/workout_provider.dart';
import '../../services/progress_service.dart';

/// Logs sets for the selected exercise, with last time's numbers, a
/// suggested target and a cheer for new records.
class ActiveExerciseTracker extends StatefulWidget {
  final Exercise exercise;
  final WorkoutProvider provider;
  final double weight;
  final int reps;
  final double weightStep;
  final void Function(double weight, int reps) onChanged;

  /// Load last time's top set into the pickers once it's known.
  final bool prefillFromLastTime;

  const ActiveExerciseTracker({
    super.key,
    required this.exercise,
    required this.provider,
    required this.weight,
    required this.reps,
    required this.onChanged,
    this.weightStep = 2.5,
    this.prefillFromLastTime = false,
  });

  @override
  State<ActiveExerciseTracker> createState() => _ActiveExerciseTrackerState();
}

class _ActiveExerciseTrackerState extends State<ActiveExerciseTracker> {
  ExerciseSession? _last;
  ExerciseRecords? _records;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ActiveExerciseTracker old) {
    super.didUpdateWidget(old);
    if (old.exercise.name != widget.exercise.name ||
        old.exercise.workoutId != widget.exercise.workoutId) {
      _load();
    }
  }

  Future<void> _load() async {
    final name = widget.exercise.name;
    final workoutId = widget.exercise.workoutId;
    final service = ProgressService();
    final sessions = await service.sessionsFor(
      name,
      excludeWorkoutId: workoutId,
    );
    if (!mounted || name != widget.exercise.name) return;
    setState(() {
      _last = sessions.firstOrNull;
      _records = ExerciseRecords.from(name, '', sessions);
    });
    final last = _last;
    if (widget.prefillFromLastTime && last != null) {
      widget.onChanged(last.topSet.weight, last.topSet.reps);
    }
  }

  /// Records so far: earlier sessions plus sets already done today.
  ExerciseRecords? _recordsIncludingToday() {
    final previous = _records;
    if (previous == null) return null;
    var bestWeight = previous.bestWeight;
    var best1rm = previous.bestOneRepMax;
    for (final s in widget.exercise.sets.where((s) => s.isCompleted)) {
      if (s.weight > bestWeight) bestWeight = s.weight;
      final e = estimatedOneRepMax(s.weight, s.reps);
      if (e > best1rm) best1rm = e;
    }
    return ExerciseRecords(
      name: previous.name,
      muscleGroup: previous.muscleGroup,
      bestWeight: bestWeight,
      repsAtBestWeight: previous.repsAtBestWeight,
      bestOneRepMax: best1rm,
      bestSessionVolume: previous.bestSessionVolume,
      sessions: previous.sessions,
      lastDone: previous.lastDone,
    );
  }

  Future<void> _complete() async {
    final exercise = widget.exercise;
    final pending = exercise.sets.where((s) => !s.isCompleted).toList();
    if (pending.isEmpty || _busy) return;
    final current = pending.first;
    final weight = widget.weight, reps = widget.reps;
    final records = newRecords(
      LoggedSet(weight, reps),
      _recordsIncludingToday(),
    );
    setState(() => _busy = true);
    try {
      await widget.provider.completeSet(current.id!, weight, reps);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (records.isNotEmpty) {
      HapticFeedback.heavyImpact();
      AppSnackbar.success(
        context,
        records.contains(RecordKind.weight)
            ? 'New record! Heaviest ${exercise.name}: '
                  '${formatWeight(weight)} kg × $reps'
            : 'New record! Best estimated max for ${exercise.name}: '
                  '${formatWeight(estimatedOneRepMax(weight, reps))} kg',
      );
      return;
    }
    final isLast = pending.length == 1;
    AppSnackbar.success(
      context,
      isLast
          ? '${exercise.name} complete — great work!'
          : 'Set ${current.setNumber} logged: '
                '${formatWeight(weight)} kg × $reps',
    );
  }

  Future<void> _typeValue({required bool isWeight}) async {
    final controller = TextEditingController(
      text: isWeight ? formatWeight(widget.weight) : '${widget.reps}',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isWeight ? 'Weight (kg)' : 'Reps'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: isWeight),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              isWeight ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
            ),
          ],
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (isWeight) {
      final v = double.tryParse(result);
      if (v != null && v >= 0 && v < 1000) widget.onChanged(v, widget.reps);
    } else {
      final v = int.tryParse(result);
      if (v != null && v >= 0 && v < 1000) widget.onChanged(widget.weight, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final hasPending = exercise.sets.any((s) => !s.isCompleted);
    final target = suggestNext(_last, increment: widget.weightStep);
    final step = widget.weightStep;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Progress for ${exercise.name}',
                icon: Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => context.push(
                  '/exercise?name=${Uri.encodeQueryComponent(exercise.name)}',
                ),
              ),
            ],
          ),
          if (_last != null) ...[
            const SizedBox(height: 12),
            _LastTime(
              last: _last!,
              target: hasPending ? target : null,
              onUse: target == null
                  ? null
                  : () => widget.onChanged(target.weight, target.reps),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _MetricPicker(
                label: 'Weight',
                value: '${formatWeight(widget.weight)} kg',
                onTapValue: () => _typeValue(isWeight: true),
                onDec: () => widget.onChanged(
                  (widget.weight - step).clamp(0, 999),
                  widget.reps,
                ),
                onInc: () => widget.onChanged(
                  (widget.weight + step).clamp(0, 999),
                  widget.reps,
                ),
              ),
              const SizedBox(width: 12),
              _MetricPicker(
                label: 'Reps',
                value: '${widget.reps}',
                onTapValue: () => _typeValue(isWeight: false),
                onDec: () => widget.onChanged(
                  widget.weight,
                  widget.reps > 0 ? widget.reps - 1 : 0,
                ),
                onInc: () => widget.onChanged(widget.weight, widget.reps + 1),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppButton(
            text: hasPending ? 'Complete Set' : 'All Sets Done',
            isLoading: _busy,
            onPressed: hasPending
                ? _complete
                : () => AppSnackbar.info(
                    context,
                    'All sets for ${exercise.name} are done. '
                    'Add a set below to keep going.',
                  ),
          ),
        ],
      ),
    );
  }
}

class _LastTime extends StatelessWidget {
  final ExerciseSession last;
  final NextTarget? target;
  final VoidCallback? onUse;

  const _LastTime({required this.last, this.target, this.onUse});

  @override
  Widget build(BuildContext context) {
    final sets = last.sets
        .map((s) => '${formatWeight(s.weight)}×${s.reps}')
        .join(', ');
    final t = target;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last time (${relativeDay(last.date)}): $sets kg',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (t != null)
                  Text(
                    t.increase
                        ? 'You held your reps. Try ${formatWeight(t.weight)} kg × ${t.reps}.'
                        : t.weight > 0
                        ? 'Aim for ${formatWeight(t.weight)} kg × ${t.reps}.'
                        : 'Aim for ${t.reps} reps.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onUse != null && t != null)
            TextButton(onPressed: onUse, child: const Text('Use')),
        ],
      ),
    );
  }
}

/// "today", "yesterday", "3 days ago", or a date.
String relativeDay(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final a = DateTime(date.year, date.month, date.day);
  final b = DateTime(today.year, today.month, today.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'last week';
  return '${date.day}/${date.month}';
}

/// A value with − and + buttons. Hold a button to repeat; tap the value to
/// type it.
class _MetricPicker extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onTapValue;

  const _MetricPicker({
    required this.label,
    required this.value,
    required this.onDec,
    required this.onInc,
    required this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
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
                _RepeatButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Decrease $label',
                  color: AppColors.textSecondary,
                  onStep: onDec,
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '$label $value. Tap to type a value.',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onTapValue,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
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
                    ),
                  ),
                ),
                _RepeatButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Increase $label',
                  color: AppColors.primary,
                  onStep: onInc,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onStep;

  const _RepeatButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onStep,
  });

  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  Timer? _timer;

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      widget.onStep();
      HapticFeedback.selectionClick();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: widget.onStep,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        icon: Icon(widget.icon, color: widget.color, size: 22),
      ),
    );
  }
}
