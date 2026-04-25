import 'package:sqflite/sqflite.dart';
import 'package:trackit/models/workouts.dart';
import 'database_service.dart';

/// Workout Service
/// Handles all workout-related database operations and calculations
class WorkoutService {
  final DatabaseService _dbService = DatabaseService();

  /// Add a new workout session
  /// Returns the inserted workout with its ID
  Future<Workout> addWorkout(Workout workout) async {
    final db = await _dbService.getDatabase();
    final id = await db.insert(
      'workouts',
      workout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return workout.copyWith(id: id as int?);
  }

  /// Add an exercise to a workout
  /// Returns the inserted exercise with its ID
  Future<Exercise> addExercise(Exercise exercise) async {
    final db = await _dbService.getDatabase();
    final id = await db.insert(
      'exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return exercise.copyWith(id: id as int?);
  }

  /// Add a set to an exercise
  /// Returns the inserted set with its ID
  Future<SetData> addSet(SetData set) async {
    final db = await _dbService.getDatabase();
    final id = await db.insert(
      'sets',
      set.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return set.copyWith(id: id as int?);
  }

  /// Get all workouts
  Future<List<Workout>> getAllWorkouts() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query('workouts', orderBy: 'timestamp DESC');
    final workouts =
        List.generate(maps.length, (i) => Workout.fromMap(maps[i]));

    // Load exercises for each workout
    for (var i = 0; i < workouts.length; i++) {
      workouts[i] = await _loadWorkoutWithExercises(workouts[i]);
    }

    return workouts;
  }

  /// Get a workout by ID with all exercises and sets
  Future<Workout?> getWorkoutById(int id) async {
    final db = await _dbService.getDatabase();
    final maps =
        await db.query('workouts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    var workout = Workout.fromMap(maps[0]);
    return await _loadWorkoutWithExercises(workout);
  }

  /// Get workouts for a specific date
  /// Returns all workouts that occurred on the given date
  Future<List<Workout>> getWorkoutsByDate(DateTime date) async {
    final db = await _dbService.getDatabase();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final maps = await db.query(
      'workouts',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );

    final workouts =
        List.generate(maps.length, (i) => Workout.fromMap(maps[i]));

    // Load exercises for each workout
    for (var i = 0; i < workouts.length; i++) {
      workouts[i] = await _loadWorkoutWithExercises(workouts[i]);
    }

    return workouts;
  }

  /// Get workouts for a specific month
  Future<List<Workout>> getWorkoutsByMonth(int year, int month) async {
    final db = await _dbService.getDatabase();
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final maps = await db.query(
      'workouts',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        startOfMonth.toIso8601String(),
        endOfMonth.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );

    final workouts =
        List.generate(maps.length, (i) => Workout.fromMap(maps[i]));

    // Load exercises for each workout
    for (var i = 0; i < workouts.length; i++) {
      workouts[i] = await _loadWorkoutWithExercises(workouts[i]);
    }

    return workouts;
  }

  /// Get workouts of a specific type
  Future<List<Workout>> getWorkoutsByType(WorkoutType type) async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'workouts',
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'timestamp DESC',
    );

    final workouts =
        List.generate(maps.length, (i) => Workout.fromMap(maps[i]));

    // Load exercises for each workout
    for (var i = 0; i < workouts.length; i++) {
      workouts[i] = await _loadWorkoutWithExercises(workouts[i]);
    }

    return workouts;
  }

  /// Helper method to load complete workout with exercises and sets
  Future<Workout> _loadWorkoutWithExercises(Workout workout) async {
    final db = await _dbService.getDatabase();

    // Get exercises for this workout
    final exerciseMaps = await db.query(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [workout.id],
    );

    final exercises = <Exercise>[];
    for (var exerciseMap in exerciseMaps) {
      var exercise = Exercise.fromMap(exerciseMap);

      // Get sets for this exercise
      final setMaps = await db.query(
        'sets',
        where: 'exercise_id = ?',
        whereArgs: [exercise.id],
        orderBy: 'set_number ASC',
      );

      final sets = List.generate(setMaps.length, (i) => SetData.fromMap(setMaps[i]));
      exercise = exercise.copyWith(sets: sets);
      exercises.add(exercise);
    }

    return workout.copyWith(exercises: exercises);
  }

  /// Calculate total volume for a specific workout session
  /// Formula: Sum of (weight * reps) for all sets in all exercises
  Future<double> calculateSessionVolume(int workoutId) async {
    final workout = await getWorkoutById(workoutId);
    if (workout == null) return 0.0;
    return workout.getTotalSessionVolume();
  }

  /// Calculate completion percentage for a specific workout session
  /// Formula: (Completed Sets / Total Sets) * 100
  Future<double> calculateSessionCompletionPercentage(int workoutId) async {
    final workout = await getWorkoutById(workoutId);
    if (workout == null) return 0.0;
    return workout.getSessionCompletionPercentage();
  }

  /// Calculate total volume for an exercise
  Future<double> calculateExerciseVolume(int exerciseId) async {
    final db = await _dbService.getDatabase();
    final result = await db.rawQuery(
      'SELECT SUM(weight * reps) as total_volume FROM sets WHERE exercise_id = ?',
      [exerciseId],
    );
    return result[0]['total_volume'] != null
        ? (result[0]['total_volume'] as num).toDouble()
        : 0.0;
  }

  /// Get completion percentage for an exercise
  /// Formula: (Completed Sets / Total Sets) * 100
  Future<double> calculateExerciseCompletionPercentage(int exerciseId) async {
    final db = await _dbService.getDatabase();

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM sets WHERE exercise_id = ?',
      [exerciseId],
    );

    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as completed FROM sets WHERE exercise_id = ? AND is_completed = 1',
      [exerciseId],
    );

    final total = (totalResult[0]['total'] as int?) ?? 0;
    final completed = (completedResult[0]['completed'] as int?) ?? 0;

    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }

  /// Get workout summary statistics
  /// Includes total volume, completed sets, and session details
  Future<Map<String, dynamic>> getWorkoutSummary(int workoutId) async {
    final workout = await getWorkoutById(workoutId);
    if (workout == null) {
      return {
        'error': 'Workout not found',
      };
    }

    return workout.getSessionSummary();
  }

  /// Get daily workout stats
  /// Returns number of workouts and total volume for a specific date
  Future<Map<String, dynamic>> getDailyWorkoutStats(DateTime date) async {
    final workouts = await getWorkoutsByDate(date);

    double totalVolume = 0.0;
    int totalCompleted = 0;
    int totalSets = 0;

    for (var workout in workouts) {
      totalVolume += workout.getTotalSessionVolume();
      totalCompleted += workout.getTotalCompletedSets();
      totalSets += workout.getTotalSets();
    }

    return {
      'date': date.toIso8601String(),
      'workoutCount': workouts.length,
      'totalVolume': totalVolume.toStringAsFixed(2),
      'completedSets': totalCompleted,
      'totalSets': totalSets,
      'completionPercentage':
          totalSets > 0 ? ((totalCompleted / totalSets) * 100).toStringAsFixed(2) : '0.00',
      'workouts': workouts.map((w) => w.getSessionSummary()).toList(),
    };
  }

  /// Get monthly workout stats
  /// Returns workout frequency and volume statistics for a month
  Future<Map<String, dynamic>> getMonthlyWorkoutStats(int year, int month) async {
    final workouts = await getWorkoutsByMonth(year, month);

    double totalVolume = 0.0;
    int totalCompleted = 0;
    int totalSets = 0;
    final typeBreakdown = <String, dynamic>{};

    // Initialize type breakdown
    for (var type in WorkoutType.values) {
      typeBreakdown[type.name] = {
        'count': 0,
        'totalVolume': 0.0,
      };
    }

    for (var workout in workouts) {
      final volume = workout.getTotalSessionVolume();
      totalVolume += volume;
      totalCompleted += workout.getTotalCompletedSets();
      totalSets += workout.getTotalSets();

      // Add to type breakdown
      final typeStats = typeBreakdown[workout.type.name];
      typeStats['count'] = (typeStats['count'] as int) + 1;
      typeStats['totalVolume'] = (typeStats['totalVolume'] as double) + volume;
    }

    return {
      'year': year,
      'month': month,
      'totalWorkouts': workouts.length,
      'totalVolume': totalVolume.toStringAsFixed(2),
      'avgVolumePerWorkout':
          workouts.isNotEmpty ? (totalVolume / workouts.length).toStringAsFixed(2) : '0.00',
      'completedSets': totalCompleted,
      'totalSets': totalSets,
      'completionPercentage':
          totalSets > 0 ? ((totalCompleted / totalSets) * 100).toStringAsFixed(2) : '0.00',
      'typeBreakdown': typeBreakdown,
    };
  }

  /// Mark a set as completed
  Future<void> completeSet(int setId) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'sets',
      {'is_completed': 1},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// Mark a set as incomplete
  Future<void> uncompleteSet(int setId) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'sets',
      {'is_completed': 0},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// Update a set's weight and reps
  Future<void> updateSet(int setId, double weight, int reps) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'sets',
      {
        'weight': weight,
        'reps': reps,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// Delete a workout and all its exercises and sets
  Future<void> deleteWorkout(int workoutId) async {
    final db = await _dbService.getDatabase();
    await db.delete(
      'workouts',
      where: 'id = ?',
      whereArgs: [workoutId],
    );
    // Sets and exercises will be deleted due to CASCADE constraint
  }

  /// Delete an exercise and all its sets
  Future<void> deleteExercise(int exerciseId) async {
    final db = await _dbService.getDatabase();
    await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
    // Sets will be deleted due to CASCADE constraint
  }

  /// Delete a set
  Future<void> deleteSet(int setId) async {
    final db = await _dbService.getDatabase();
    await db.delete(
      'sets',
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// Get personal records for a specific exercise
  /// Returns the heaviest weight lifted for a specific exercise
  Future<Map<String, dynamic>> getExercisePR(String exerciseName) async {
    final db = await _dbService.getDatabase();
    final result = await db.rawQuery(
      '''SELECT MAX(weight) as max_weight, reps FROM sets 
         INNER JOIN exercises ON sets.exercise_id = exercises.id 
         WHERE exercises.name = ? AND sets.is_completed = 1 
         GROUP BY reps 
         ORDER BY max_weight DESC LIMIT 1''',
      [exerciseName],
    );

    if (result.isEmpty) {
      return {
        'exerciseName': exerciseName,
        'hasRecord': false,
      };
    }

    return {
      'exerciseName': exerciseName,
      'hasRecord': true,
      'maxWeight': (result[0]['max_weight'] as num?)?.toDouble() ?? 0.0,
      'reps': result[0]['reps'],
    };
  }

  /// Get weekly workout volume data
  Future<Map<DateTime, double>> getWeeklyVolumeData() async {
    final now = DateTime.now();
    final data = <DateTime, double>{};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final workouts = await getWorkoutsByDate(date);
      double totalVolume = 0;
      for (var workout in workouts) {
        totalVolume += workout.getTotalSessionVolume();
      }
      data[DateTime(date.year, date.month, date.day)] = totalVolume;
    }
    return data;
  }

  /// Add a new routine
  Future<Routine> addRoutine(Routine routine) async {
    final db = await _dbService.getDatabase();
    final id = await db.insert('routines', routine.toMap());
    
    final savedExercises = <RoutineExercise>[];
    for (var exercise in routine.exercises) {
      final exerciseId = await db.insert('routine_exercises', 
        exercise.toMap()..['routine_id'] = id);
      savedExercises.add(exercise.copyWith(id: exerciseId, routineId: id as int));
    }
    
    return routine.copyWith(id: id as int, exercises: savedExercises);
  }

  /// Get all routines
  Future<List<Routine>> getAllRoutines() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query('routines');
    final routines = <Routine>[];
    
    for (var map in maps) {
      var routine = Routine.fromMap(map);
      final exerciseMaps = await db.query('routine_exercises', 
        where: 'routine_id = ?', whereArgs: [routine.id]);
      final exercises = exerciseMaps.map((e) => RoutineExercise.fromMap(e)).toList();
      routines.add(routine.copyWith(exercises: exercises));
    }
    
    return routines;
  }

  /// Start a workout session from a routine
  Future<Workout> startWorkoutFromRoutine(Routine routine) async {
    final workout = await addWorkout(Workout(
      type: routine.type,
      timestamp: DateTime.now(),
      notes: 'Routine: ${routine.name}',
    ));

    for (var routineEx in routine.exercises) {
      final exercise = await addExercise(Exercise(
        workoutId: workout.id!,
        name: routineEx.name,
        muscleGroup: routineEx.muscleGroup,
      ));

      for (int i = 0; i < routineEx.setsCount; i++) {
        await addSet(SetData(
          exerciseId: exercise.id!,
          setNumber: i + 1,
          weight: 0,
          reps: 0,
        ));
      }
    }

    return await getWorkoutById(workout.id!) ?? workout;
  }

  /// Delete a routine
  Future<void> deleteRoutine(int id) async {
    final db = await _dbService.getDatabase();
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }
}
