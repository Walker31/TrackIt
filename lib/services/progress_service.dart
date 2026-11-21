import '../models/workouts.dart';
import 'database_service.dart';

/// Estimated one-rep max (Epley). A single rep is the lift itself.
double estimatedOneRepMax(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

/// One completed set, as history sees it.
class LoggedSet {
  final double weight;
  final int reps;
  const LoggedSet(this.weight, this.reps);

  double get volume => weight * reps;
  double get oneRepMax => estimatedOneRepMax(weight, reps);

  @override
  String toString() => '$weight×$reps';
}

/// Everything done for one exercise in one workout.
class ExerciseSession {
  final int workoutId;
  final DateTime date;
  final List<LoggedSet> sets;

  const ExerciseSession({
    required this.workoutId,
    required this.date,
    required this.sets,
  });

  /// The heaviest set; among equal weights, the one with most reps.
  LoggedSet get topSet => sets.reduce(
    (a, b) => b.weight > a.weight || (b.weight == a.weight && b.reps > a.reps)
        ? b
        : a,
  );

  double get volume => sets.fold(0, (sum, s) => sum + s.volume);
  double get bestOneRepMax =>
      sets.fold(0, (best, s) => s.oneRepMax > best ? s.oneRepMax : best);
}

/// What to aim for next time, from the last session.
class NextTarget {
  final double weight;
  final int reps;

  /// True when the suggestion adds weight rather than repeating it.
  final bool increase;

  const NextTarget(this.weight, this.reps, {required this.increase});
}

/// Simple progressive overload: if every set at the top weight kept the
/// first set's reps, add [increment]; otherwise repeat the weight and aim
/// for one more rep.
NextTarget? suggestNext(ExerciseSession? last, {double increment = 2.5}) {
  if (last == null || last.sets.isEmpty) return null;
  final top = last.topSet;
  if (top.weight <= 0) {
    // Bodyweight work: chase reps.
    return NextTarget(0, top.reps + 1, increase: false);
  }
  final atTop = last.sets.where((s) => s.weight == top.weight).toList();
  final target = atTop.first.reps;
  final heldReps = atTop.every((s) => s.reps >= target);
  return heldReps
      ? NextTarget(top.weight + increment, target, increase: true)
      : NextTarget(top.weight, target + 1, increase: false);
}

/// Best marks for one exercise.
class ExerciseRecords {
  final String name;
  final String muscleGroup;
  final double bestWeight;
  final int repsAtBestWeight;
  final double bestOneRepMax;
  final double bestSessionVolume;
  final int sessions;
  final DateTime lastDone;

  const ExerciseRecords({
    required this.name,
    required this.muscleGroup,
    required this.bestWeight,
    required this.repsAtBestWeight,
    required this.bestOneRepMax,
    required this.bestSessionVolume,
    required this.sessions,
    required this.lastDone,
  });

  static ExerciseRecords? from(
    String name,
    String muscleGroup,
    List<ExerciseSession> sessions,
  ) {
    if (sessions.isEmpty) return null;
    var bestWeight = 0.0, repsAtBest = 0, best1rm = 0.0, bestVolume = 0.0;
    var last = sessions.first.date;
    for (final s in sessions) {
      final top = s.topSet;
      if (top.weight > bestWeight ||
          (top.weight == bestWeight && top.reps > repsAtBest)) {
        bestWeight = top.weight;
        repsAtBest = top.reps;
      }
      if (s.bestOneRepMax > best1rm) best1rm = s.bestOneRepMax;
      if (s.volume > bestVolume) bestVolume = s.volume;
      if (s.date.isAfter(last)) last = s.date;
    }
    return ExerciseRecords(
      name: name,
      muscleGroup: muscleGroup,
      bestWeight: bestWeight,
      repsAtBestWeight: repsAtBest,
      bestOneRepMax: best1rm,
      bestSessionVolume: bestVolume,
      sessions: sessions.length,
      lastDone: last,
    );
  }
}

/// Which records a new set beats.
enum RecordKind { weight, oneRepMax }

/// Records [set] would set against [previous] (earlier sessions only).
/// Nothing counts on the first ever session: every set would be a "record".
Set<RecordKind> newRecords(LoggedSet set, ExerciseRecords? previous) {
  if (previous == null || set.weight <= 0 || set.reps <= 0) return {};
  return {
    if (set.weight > previous.bestWeight) RecordKind.weight,
    if (set.oneRepMax > previous.bestOneRepMax + 0.01) RecordKind.oneRepMax,
  };
}

/// Read-only views over logged workouts: history, last time and records.
class ProgressService {
  final DatabaseService _db = DatabaseService();

  static String _key(String name) => name.trim().toLowerCase();

  /// Completed sets of [exerciseName] grouped by workout, newest first.
  /// [excludeWorkoutId] leaves out the session being logged now.
  Future<List<ExerciseSession>> sessionsFor(
    String exerciseName, {
    int? excludeWorkoutId,
  }) async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery(
      '''
      SELECT w.id AS workout_id, w.timestamp, s.weight, s.reps
      FROM sets s
      JOIN exercises e ON e.id = s.exercise_id
      JOIN workouts w ON w.id = e.workout_id
      WHERE LOWER(TRIM(e.name)) = ? AND s.is_completed = 1
        AND (? IS NULL OR w.id != ?)
      ORDER BY w.timestamp DESC, w.id DESC, e.id ASC, s.set_number ASC
      ''',
      [_key(exerciseName), excludeWorkoutId, excludeWorkoutId],
    );
    return _group(rows);
  }

  static List<ExerciseSession> _group(List<Map<String, Object?>> rows) {
    final sessions = <ExerciseSession>[];
    for (final row in rows) {
      final id = row['workout_id'] as int;
      final set = LoggedSet(
        double.tryParse('${row['weight']}') ?? 0,
        (row['reps'] as num?)?.toInt() ?? 0,
      );
      if (sessions.isNotEmpty && sessions.last.workoutId == id) {
        sessions.last.sets.add(set);
      } else {
        sessions.add(
          ExerciseSession(
            workoutId: id,
            date: DateTime.parse(row['timestamp'] as String),
            sets: [set],
          ),
        );
      }
    }
    return sessions;
  }

  /// The most recent earlier session of [exerciseName], if any.
  Future<ExerciseSession?> lastSession(
    String exerciseName, {
    int? excludeWorkoutId,
  }) async {
    final all = await sessionsFor(
      exerciseName,
      excludeWorkoutId: excludeWorkoutId,
    );
    return all.firstOrNull;
  }

  /// Records for [exerciseName] from sessions other than [excludeWorkoutId].
  Future<ExerciseRecords?> recordsFor(
    String exerciseName, {
    int? excludeWorkoutId,
  }) async {
    final sessions = await sessionsFor(
      exerciseName,
      excludeWorkoutId: excludeWorkoutId,
    );
    return ExerciseRecords.from(exerciseName, '', sessions);
  }

  /// Records for every exercise ever completed, most recently done first.
  Future<List<ExerciseRecords>> allRecords() async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery('''
      SELECT e.name, e.muscle_group, w.id AS workout_id, w.timestamp,
             s.weight, s.reps
      FROM sets s
      JOIN exercises e ON e.id = s.exercise_id
      JOIN workouts w ON w.id = e.workout_id
      WHERE s.is_completed = 1
      ORDER BY w.timestamp DESC, w.id DESC, e.id ASC, s.set_number ASC
    ''');
    final byName = <String, List<Map<String, Object?>>>{};
    final display = <String, (String, String)>{};
    for (final row in rows) {
      final name = row['name'] as String;
      final key = _key(name);
      byName.putIfAbsent(key, () => []).add(row);
      final muscle = (row['muscle_group'] as String?) ?? '';
      final prev = display[key];
      // Keep the newest spelling, and any muscle group we've seen.
      display[key] = (
        prev?.$1 ?? name.trim(),
        (prev?.$2.isNotEmpty ?? false) ? prev!.$2 : muscle,
      );
    }
    final records = <ExerciseRecords>[];
    for (final entry in byName.entries) {
      final (name, muscle) = display[entry.key]!;
      final r = ExerciseRecords.from(name, muscle, _group(entry.value));
      if (r != null) records.add(r);
    }
    records.sort((a, b) => b.lastDone.compareTo(a.lastDone));
    return records;
  }

  /// Past workouts with at least one exercise, newest first.
  Future<List<Workout>> history({int limit = 30, int offset = 0}) async {
    final db = await _db.getDatabase();
    final maps = await db.rawQuery(
      '''
      SELECT w.* FROM workouts w
      WHERE EXISTS (SELECT 1 FROM exercises e WHERE e.workout_id = w.id)
      ORDER BY w.timestamp DESC, w.id DESC
      LIMIT ? OFFSET ?
      ''',
      [limit, offset],
    );
    return [
      for (final m in maps) await workout(m['id'] as int),
    ].nonNulls.toList();
  }

  /// One workout with its exercises and sets.
  Future<Workout?> workout(int id) async {
    final db = await _db.getDatabase();
    final maps = await db.query('workouts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final exercises = <Exercise>[];
    final exMaps = await db.query(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    for (final ex in exMaps) {
      final sets = await db.query(
        'sets',
        where: 'exercise_id = ?',
        whereArgs: [ex['id']],
        orderBy: 'set_number ASC',
      );
      exercises.add(
        Exercise.fromMap(ex).copyWith(sets: sets.map(SetData.fromMap).toList()),
      );
    }
    return Workout.fromMap(maps.first).copyWith(exercises: exercises);
  }

  /// Days in a row (ending today or yesterday) with a completed set.
  Future<int> streak({DateTime? now}) async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery('''
      SELECT DISTINCT substr(w.timestamp, 1, 10) AS day
      FROM workouts w
      JOIN exercises e ON e.workout_id = w.id
      JOIN sets s ON s.exercise_id = e.id
      WHERE s.is_completed = 1
    ''');
    final days = {for (final r in rows) r['day'] as String};
    return countStreak(days, now ?? DateTime.now());
  }
}

/// Consecutive days in [days] (yyyy-MM-dd) ending today, or yesterday if
/// today has nothing yet.
int countStreak(Set<String> days, DateTime now) {
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  var day = DateTime(now.year, now.month, now.day);
  if (!days.contains(key(day))) day = day.subtract(const Duration(days: 1));
  var count = 0;
  while (days.contains(key(day))) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}
