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

  WorkoutProvider() {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SyncService().performSync();
      final now = DateTime.now();
      final workouts = await _service.getWorkoutsByDate(now);
      if (workouts.isNotEmpty) {
        _todayWorkout = workouts.first;
      } else {
        _todayWorkout = await _service.addWorkout(
          Workout(
            type: WorkoutType.push,
            timestamp: now,
            notes: 'Daily Session',
          ),
        );
      }
      _routines = await _service.getAllRoutines();
    } catch (e) {
      debugPrint('Error refreshing workouts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRoutine(Routine routine) async {
    await _service.addRoutine(routine);
    await refreshData();
  }

  Future<void> startWorkoutFromRoutine(Routine routine) async {
    _todayWorkout = await _service.startWorkoutFromRoutine(routine);
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise) async {
    await _service.addExercise(exercise);
    await refreshData();
  }

  Future<void> addSet(SetData setData) async {
    await _service.addSet(setData);
    await refreshData();
  }

  Future<void> completeSet(int setId, double weight, int reps) async {
    await _service.updateSet(setId, weight, reps);
    await _service.completeSet(setId);
    await refreshData();
    HapticFeedback.mediumImpact(); // Feedback on set completion
    startRestTimer(); // Start timer after completion
  }
}
