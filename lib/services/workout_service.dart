import 'package:sqflite/sqflite.dart' show DatabaseExecutor;
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'sync_outbox.dart';
import '../models/workouts.dart';

class WorkoutService {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();

  /// Add a new workout session (Offline-first)
  Future<Workout> addWorkout(Workout workout) async {
    final db = await _dbService.getDatabase();

    // Save locally
    final map = workout.toMap();
    map['is_synced'] = 0;
    map.remove('exercises'); // Nested list doesn't go into sqlite directly

    final localId = await db.insert('workouts', map);
    final savedWorkout = workout.copyWith(id: localId);

    // Try sync
    _syncService.performSync();

    return savedWorkout;
  }

  /// Get all workouts (from local cache)
  Future<List<Workout>> getAllWorkouts() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query('workouts', orderBy: 'timestamp DESC');

    final workouts = <Workout>[];
    for (var map in maps) {
      final workout = Workout.fromMap(map);
      workouts.add(await _loadWorkoutWithExercises(workout));
    }
    return workouts;
  }

  /// Get workouts for a specific date
  Future<List<Workout>> getWorkoutsByDate(DateTime date) async {
    final db = await _dbService.getDatabase();
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();

    final maps = await db.query(
      'workouts',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp DESC',
    );

    final workouts = <Workout>[];
    for (var map in maps) {
      final workout = Workout.fromMap(map);
      workouts.add(await _loadWorkoutWithExercises(workout));
    }
    return workouts;
  }

  Future<Workout> _loadWorkoutWithExercises(Workout workout) async {
    final db = await _dbService.getDatabase();
    final exerciseMaps = await db.query(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [workout.id],
    );

    final exercises = <Exercise>[];
    for (var exMap in exerciseMaps) {
      final setMaps = await db.query(
        'sets',
        where: 'exercise_id = ?',
        whereArgs: [exMap['id']],
        orderBy: 'set_number ASC',
      );
      final sets = setMaps.map((s) => SetData.fromMap(s)).toList();
      exercises.add(Exercise.fromMap(exMap).copyWith(sets: sets));
    }
    return workout.copyWith(exercises: exercises);
  }

  /// Add an exercise
  Future<Exercise> addExercise(Exercise exercise) async {
    final db = await _dbService.getDatabase();

    final localId = await db.transaction((txn) async {
      final localId = await txn.insert('exercises', {
        'workout_id': exercise.workoutId,
        'name': exercise.name,
        'muscle_group': exercise.muscleGroup,
        'is_synced': 0,
      });

      for (final s in exercise.sets) {
        await txn.insert('sets', {
          'exercise_id': localId,
          'set_number': s.setNumber,
          'weight': s.weight,
          'reps': s.reps,
          'is_completed': s.isCompleted ? 1 : 0,
          'is_synced': 0,
        });
      }

      await _markWorkoutDirty(txn, exercise.workoutId);
      return localId;
    });
    _syncService.performSync();
    return exercise.copyWith(id: localId);
  }

  /// Add a set
  Future<SetData> addSet(SetData setData) async {
    final db = await _dbService.getDatabase();
    final localId = await db.insert('sets', {
      'exercise_id': setData.exerciseId,
      'set_number': setData.setNumber,
      'weight': setData.weight,
      'reps': setData.reps,
      'is_completed': setData.isCompleted ? 1 : 0,
      'is_synced': 0,
    });
    await _markDirtyForExercise(db, setData.exerciseId);
    _syncService.performSync();
    return setData.copyWith(id: localId);
  }

  /// Update a set
  Future<void> updateSet(int setId, double weight, int reps) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'sets',
      {'weight': weight, 'reps': reps, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [setId],
    );
    await _markDirtyForSet(db, setId);
    _syncService.performSync();
  }

  /// Complete a set, optionally saving its final weight and reps in the
  /// same write (one sync instead of two).
  Future<void> completeSet(int setId, {double? weight, int? reps}) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'sets',
      {'is_completed': 1, 'is_synced': 0, 'weight': ?weight, 'reps': ?reps},
      where: 'id = ?',
      whereArgs: [setId],
    );
    await _markDirtyForSet(db, setId);
    _syncService.performSync();
  }

  /// Uncomplete a set
  Future<void> uncompleteSet(int setId) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'sets',
      {'is_completed': 0, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [setId],
    );
    await _markDirtyForSet(db, setId);
    _syncService.performSync();
  }

  // The server stores a workout with its exercises and sets nested, so any
  // child change means the whole workout has to be pushed again.
  Future<void> _markWorkoutDirty(DatabaseExecutor db, int workoutId) =>
      db.update(
        'workouts',
        {'is_synced': 0},
        where: 'id = ?',
        whereArgs: [workoutId],
      );

  Future<void> _markDirtyForExercise(
    DatabaseExecutor db,
    int exerciseId,
  ) async {
    final rows = await db.query(
      'exercises',
      columns: ['workout_id'],
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
    if (rows.isNotEmpty) {
      await _markWorkoutDirty(db, rows.first['workout_id'] as int);
    }
  }

  Future<void> _markDirtyForSet(DatabaseExecutor db, int setId) async {
    final rows = await db.query(
      'sets',
      columns: ['exercise_id'],
      where: 'id = ?',
      whereArgs: [setId],
    );
    if (rows.isNotEmpty) {
      await _markDirtyForExercise(db, rows.first['exercise_id'] as int);
    }
  }

  /// Get routines
  Future<List<Routine>> getAllRoutines() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query('routines');
    final routines = <Routine>[];
    for (var map in maps) {
      var routine = Routine.fromMap(map);
      final exMaps = await db.query(
        'routine_exercises',
        where: 'routine_id = ?',
        whereArgs: [routine.id],
      );
      final exercises = exMaps.map((e) => RoutineExercise.fromMap(e)).toList();
      routines.add(routine.copyWith(exercises: exercises));
    }
    return routines;
  }

  Future<Routine> addRoutine(Routine routine) async {
    final db = await _dbService.getDatabase();
    final rMap = routine.toMap();
    rMap['is_synced'] = 0;
    rMap.remove('routine_exercises');

    final localId = await db.transaction((txn) async {
      final localId = await txn.insert('routines', rMap);
      for (var ex in routine.exercises) {
        final exMap = ex.toMap();
        exMap['routine_id'] = localId;
        await txn.insert('routine_exercises', exMap);
      }
      return localId;
    });

    _syncService.performSync();
    return routine.copyWith(id: localId);
  }

  /// Delete a routine (its exercises cascade).
  Future<void> deleteRoutine(int id) async {
    final db = await _dbService.getDatabase();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'routines',
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty && rows.first['remote_id'] != null) {
        await SyncOutbox.enqueueDelete(
          txn,
          '${ApiService.routinesPath}${rows.first['remote_id']}/',
        );
      }
      await txn.delete('routines', where: 'id = ?', whereArgs: [id]);
    });
    _syncService.performSync();
  }

  /// Start a workout from a routine template
  Future<Workout> startWorkoutFromRoutine(Routine routine) async {
    final db = await _dbService.getDatabase();
    final now = DateTime.now();

    // One transaction, so a sync never pushes a half-built session.
    final workoutId = await db.transaction((txn) async {
      final workoutId = await txn.insert('workouts', {
        'type': routine.type.name,
        'timestamp': now.toIso8601String(),
        'notes': 'Started from ${routine.name}',
        'is_synced': 0,
      });

      for (final routineExercise in routine.exercises) {
        final exerciseId = await txn.insert('exercises', {
          'workout_id': workoutId,
          'name': routineExercise.name,
          'muscle_group': routineExercise.muscleGroup,
          'is_synced': 0,
        });

        for (int i = 1; i <= routineExercise.setsCount; i++) {
          await txn.insert('sets', {
            'exercise_id': exerciseId,
            'set_number': i,
            'weight': 0.0,
            'reps': 0,
            'is_completed': 0,
            'is_synced': 0,
          });
        }
      }
      return workoutId;
    });

    _syncService.performSync();

    return Workout(
      id: workoutId,
      type: routine.type,
      timestamp: now,
      notes: 'Started from ${routine.name}',
    );
  }

  /// Get last 7 days of workout volume totals (including today)
  Future<Map<DateTime, double>> getWeeklyVolumeData() async {
    final db = await _dbService.getDatabase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 6));
    final endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final weeklyData = <DateTime, double>{
      for (int i = 0; i < 7; i++) startDate.add(Duration(days: i)): 0.0,
    };

    final rows = await db.rawQuery(
      '''
      SELECT w.timestamp AS workout_timestamp, s.weight, s.reps, s.is_completed
      FROM workouts w
      LEFT JOIN exercises e ON e.workout_id = w.id
      LEFT JOIN sets s ON s.exercise_id = e.id
      WHERE w.timestamp >= ? AND w.timestamp <= ?
      ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    for (final row in rows) {
      final timestamp = row['workout_timestamp'] as String?;
      if (timestamp == null) continue;

      final day = DateTime.parse(timestamp);
      final dayKey = DateTime(day.year, day.month, day.day);
      if (!weeklyData.containsKey(dayKey)) continue;

      final isCompletedRaw = row['is_completed'];
      final isCompleted = isCompletedRaw == 1 || isCompletedRaw == true;
      if (!isCompleted) continue;

      final weight = double.tryParse((row['weight'] ?? 0).toString()) ?? 0.0;
      final reps = int.tryParse((row['reps'] ?? 0).toString()) ?? 0;
      weeklyData[dayKey] = (weeklyData[dayKey] ?? 0.0) + (weight * reps);
    }

    return weeklyData;
  }

  /// Delete workout
  Future<void> deleteWorkout(int id) async {
    final db = await _dbService.getDatabase();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'workouts',
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty && rows.first['remote_id'] != null) {
        await SyncOutbox.enqueueDelete(
          txn,
          'fitness/workouts/${rows.first['remote_id']}/',
        );
      }
      await txn.delete('workouts', where: 'id = ?', whereArgs: [id]);
    });
  }
}
