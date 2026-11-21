import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workouts.dart';
import '../services/workout_service.dart';
import '../services/sync_service.dart';
import '../services/prefs_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutService _service = WorkoutService();

  Workout? _todayWorkout;
  List<Routine> _routines = [];
  bool _isLoading = false;

  // Rest timer: counts down to an end time, so it stays right while the
  // app is in the background, where a notification marks the end.
  int _restTimeRemaining = 0;
  int _restTotal = 0;
  DateTime? _restEndsAt;
  Timer? _restTimer;
  int _defaultRest = 90;
  static const _restNotificationId = 4201;

  Workout? get todayWorkout => _todayWorkout;
  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;
  int get restTimeRemaining => _restTimeRemaining;
  int get restTotal => _restTotal;
  int get defaultRest => _defaultRest;
  bool get isTimerRunning => _restTimeRemaining > 0;

  Future<void> setDefaultRest(int seconds) async {
    _defaultRest = seconds.clamp(15, 600);
    notifyListeners();
    await PrefsService().set(PrefsService.restSeconds, '$_defaultRest');
  }

  void startRestTimer([int? seconds]) {
    _restTotal = seconds ?? _defaultRest;
    _restEndsAt = DateTime.now().add(Duration(seconds: _restTotal));
    _restTimeRemaining = _restTotal;
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _scheduleRestNotification();
    notifyListeners();
  }

  /// Adds (or, when negative, removes) time from a running timer.
  void adjustRestTimer(int seconds) {
    final ends = _restEndsAt;
    if (ends == null || !isTimerRunning) return;
    _restEndsAt = ends.add(Duration(seconds: seconds));
    _restTotal = (_restTotal + seconds).clamp(1, 3600);
    _tick();
    if (isTimerRunning) _scheduleRestNotification();
  }

  void _tick() {
    final ends = _restEndsAt;
    final left = ends == null
        ? 0
        : (ends.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    if (left <= 0) {
      _restTimer?.cancel();
      _restEndsAt = null;
      _restTimeRemaining = 0;
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
      NotificationService().cancel(_restNotificationId);
    } else {
      _restTimeRemaining = left;
    }
    notifyListeners();
  }

  void _scheduleRestNotification() {
    final ends = _restEndsAt;
    if (ends == null) return;
    NotificationService().scheduleOnce(
      id: _restNotificationId,
      title: 'Rest over',
      body: 'Time for your next set.',
      at: ends,
    );
  }

  void cancelTimer() {
    _restTimer?.cancel();
    _restEndsAt = null;
    _restTimeRemaining = 0;
    NotificationService().cancel(_restNotificationId);
    notifyListeners();
  }

  StreamSubscription<void>? _syncSub;

  WorkoutProvider() {
    // Background syncs (started by writes) land after the screen has read
    // the database; reload whenever one completes.
    _syncSub = SyncService().onSyncComplete.listen((_) => _reload());
    PrefsService()
        .getInt(PrefsService.restSeconds, 90)
        .then((v) {
          _defaultRest = v;
          notifyListeners();
        })
        .catchError((_) {});
    refreshData();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  /// Show what's on the device straight away, then sync. Completes after
  /// the sync (for pull-to-refresh); [onSyncComplete] reloads the result.
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _reload(notify: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await SyncService().performSync(forcePull: true);
  }

  /// Re-read today's session and routines from the local database.
  Future<void> _reload({bool notify = true}) async {
    try {
      final now = DateTime.now();
      final workouts = await _service.getWorkoutsByDate(now);
      // With nothing logged yet, show an unsaved session. It's written on
      // the first exercise, so opening the app never creates (and syncs)
      // an empty workout, or a duplicate of one still being pulled.
      // Prefer a session with exercises over an empty one (older builds
      // created an empty session on every fresh start).
      _todayWorkout = workouts.isNotEmpty
          ? workouts.firstWhere(
              (w) => w.exercises.isNotEmpty,
              orElse: () => workouts.first,
            )
          : Workout(
              type: WorkoutType.push,
              timestamp: now,
              notes: 'Daily Session',
            );
      _routines = await _service.getAllRoutines();
    } catch (e) {
      debugPrint('Error refreshing workouts: $e');
    }
    if (notify) notifyListeners();
  }

  Future<void> addRoutine(Routine routine) async {
    await _service.addRoutine(routine);
    await _reload();
  }

  Future<void> deleteRoutine(int routineId) async {
    await _service.deleteRoutine(routineId);
    await _reload();
  }

  Future<void> startWorkoutFromRoutine(Routine routine) async {
    _todayWorkout = await _service.startWorkoutFromRoutine(routine);
    notifyListeners();
    await _reload();
  }

  /// Saves the unsaved placeholder session, if today has none yet.
  Future<Workout?> _ensureSaved({WorkoutType? type, String? notes}) async {
    var workout = _todayWorkout;
    if (workout == null) return null;
    if (workout.id == null) {
      workout = await _service.addWorkout(
        workout.copyWith(type: type, notes: notes, timestamp: DateTime.now()),
      );
      _todayWorkout = workout;
    }
    return workout;
  }

  Future<void> addExercise(Exercise exercise) async {
    final workout = await _ensureSaved();
    if (workout == null) return;
    await _service.addExercise(exercise.copyWith(workoutId: workout.id));
    await _reload();
  }

  Future<void> addSet(SetData setData) async {
    await _service.addSet(setData);
    await _reload();
  }

  Future<void> completeSet(int setId, double weight, int reps) async {
    // Writes are local; the service syncs in the background.
    await _service.completeSet(setId, weight: weight, reps: reps);
    await _reload();
    HapticFeedback.mediumImpact(); // Feedback on set completion
    startRestTimer(); // Start timer after completion
    unawaited(ReminderService().reschedule());
  }

  Future<void> uncompleteSet(int setId) async {
    await _service.uncompleteSet(setId);
    await _reload();
  }

  /// Adds one more set to [exercise], copying the last set's numbers.
  Future<void> addSetTo(Exercise exercise) async {
    final last = exercise.sets.lastOrNull;
    await _service.addSet(
      SetData(
        exerciseId: exercise.id!,
        setNumber: exercise.sets.length + 1,
        weight: last?.weight ?? 0,
        reps: last?.reps ?? 0,
      ),
    );
    await _reload();
  }

  Future<void> deleteSet(int setId) async {
    await _service.deleteSet(setId);
    await _reload();
  }

  Future<void> deleteExercise(int exerciseId) async {
    await _service.deleteExercise(exerciseId);
    await _reload();
  }

  /// Puts back an exercise removed by [deleteExercise] (undo).
  Future<void> restoreExercise(Exercise exercise) async {
    final workout = await _ensureSaved();
    if (workout == null) return;
    await _service.addExercise(exercise.copyWith(workoutId: workout.id));
    await _reload();
  }

  /// Adds a past workout's exercises to today's session, each set filled
  /// in with last time's numbers and not yet done.
  Future<void> repeatWorkout(Workout past) async {
    final workout = await _ensureSaved(type: past.type, notes: past.notes);
    if (workout == null) return;
    for (final ex in past.exercises) {
      await _service.addExercise(
        Exercise(
          workoutId: workout.id!,
          name: ex.name,
          muscleGroup: ex.muscleGroup,
          sets: [
            for (final s in ex.sets)
              SetData(
                exerciseId: 0,
                setNumber: s.setNumber,
                weight: s.weight,
                reps: s.reps,
              ),
          ],
        ),
      );
    }
    await _reload();
  }

  Future<void> deleteWorkout(int workoutId) async {
    await _service.deleteWorkout(workoutId);
    await _reload();
  }
}
