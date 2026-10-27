import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workouts.dart';
import '../services/workout_service.dart';
import '../services/sync_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutService _service = WorkoutService();

  Workout? _todayWorkout;
  List<Routine> _routines = [];
  bool _isLoading = false;

  // Rest Timer State
  int _restTimeRemaining = 0;
  Timer? _restTimer;
  final int _totalRestTime = 60; // Default 60 seconds

  Workout? get todayWorkout => _todayWorkout;
  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;
  int get restTimeRemaining => _restTimeRemaining;
  bool get isTimerRunning => _restTimeRemaining > 0;

  void startRestTimer([int? seconds]) {
    _restTimer?.cancel();
    _restTimeRemaining = seconds ?? _totalRestTime;
    notifyListeners();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining > 0) {
        _restTimeRemaining--;
        notifyListeners();
      } else {
        _restTimer?.cancel();
        HapticFeedback.vibrate(); // Vibrate when timer ends
        notifyListeners();
      }
    });
  }

  void cancelTimer() {
    _restTimer?.cancel();
    _restTimeRemaining = 0;
    notifyListeners();
  }

  StreamSubscription<void>? _syncSub;

  WorkoutProvider() {
    // Background syncs (started by writes) land after the screen has read
    // the database; reload whenever one completes.
    _syncSub = SyncService().onSyncComplete.listen((_) => _reload());
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
  }

  Future<void> addExercise(Exercise exercise) async {
    var workout = _todayWorkout;
    if (workout == null) return;
    if (workout.id == null) {
      // First exercise of the day: save the placeholder session now.
      workout = await _service.addWorkout(
        workout.copyWith(timestamp: DateTime.now()),
      );
      _todayWorkout = workout;
    }
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
  }
}
