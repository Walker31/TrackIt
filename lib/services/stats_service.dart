import 'database_service.dart';

enum StatsRange {
  week('Week', 'Last 7 days'),
  month('Month', 'Last 30 days'),
  year('Year', 'Last 12 months');

  final String label;
  final String caption;
  const StatsRange(this.label, this.caption);

  /// Monthly buckets for a year; daily otherwise.
  bool get monthly => this == StatsRange.year;
}

/// One bar: the bucket's first day and its value.
typedef StatPoint = ({DateTime start, double value});

/// The buckets for [range] ending on [now]'s day.
List<DateTime> bucketsFor(StatsRange range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (range) {
    StatsRange.week => [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ],
    StatsRange.month => [
      for (var i = 29; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ],
    StatsRange.year => [
      for (var i = 11; i >= 0; i--) DateTime(today.year, today.month - i),
    ],
  };
}

/// The first day after the last bucket of [range].
DateTime rangeEnd(StatsRange range, DateTime now) => range.monthly
    ? DateTime(now.year, now.month + 1)
    : DateTime(now.year, now.month, now.day + 1);

/// Sums [rows] (a `day` yyyy-MM-dd and a `total`) into [range]'s buckets.
List<StatPoint> bucketize(
  StatsRange range,
  DateTime now,
  Iterable<Map<String, Object?>> rows,
) {
  final buckets = bucketsFor(range, now);
  final totals = {for (final b in buckets) b: 0.0};
  for (final r in rows) {
    final day = DateTime.tryParse(r['day'] as String? ?? '');
    if (day == null) continue;
    final key = range.monthly ? DateTime(day.year, day.month) : day;
    if (totals.containsKey(key)) {
      totals[key] = totals[key]! + ((r['total'] as num?)?.toDouble() ?? 0);
    }
  }
  return [for (final b in buckets) (start: b, value: totals[b]!)];
}

/// Aggregates for the Stats tab over a chosen range.
class StatsService {
  final DatabaseService _db = DatabaseService();

  Future<List<StatPoint>> spending(StatsRange range, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final db = await _db.getDatabase();
    final rows = await db.rawQuery(
      "SELECT substr(timestamp, 1, 10) AS day, SUM(amount) AS total "
      "FROM expenses WHERE type != 'income' AND timestamp >= ? "
      'AND timestamp < ? GROUP BY day',
      [
        bucketsFor(range, at).first.toIso8601String(),
        rangeEnd(range, at).toIso8601String(),
      ],
    );
    return bucketize(range, at, rows);
  }

  Future<List<StatPoint>> volume(StatsRange range, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final db = await _db.getDatabase();
    final rows = await db.rawQuery(
      '''
      SELECT substr(w.timestamp, 1, 10) AS day,
             SUM(CAST(s.weight AS REAL) * s.reps) AS total
      FROM workouts w
      JOIN exercises e ON e.workout_id = w.id
      JOIN sets s ON s.exercise_id = e.id
      WHERE s.is_completed = 1 AND w.timestamp >= ? AND w.timestamp < ?
      GROUP BY day
      ''',
      [
        bucketsFor(range, at).first.toIso8601String(),
        rangeEnd(range, at).toIso8601String(),
      ],
    );
    return bucketize(range, at, rows);
  }

  /// Completed sets per muscle group in [range], most trained first.
  /// Exercises without a group are counted as "Other".
  Future<List<({String group, int sets})>> muscleSets(
    StatsRange range, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final db = await _db.getDatabase();
    final rows = await db.rawQuery(
      '''
      SELECT TRIM(e.muscle_group) AS grp, COUNT(*) AS sets
      FROM workouts w
      JOIN exercises e ON e.workout_id = w.id
      JOIN sets s ON s.exercise_id = e.id
      WHERE s.is_completed = 1 AND w.timestamp >= ? AND w.timestamp < ?
      GROUP BY LOWER(TRIM(e.muscle_group))
      ORDER BY sets DESC
      ''',
      [
        bucketsFor(range, at).first.toIso8601String(),
        rangeEnd(range, at).toIso8601String(),
      ],
    );
    final out = <String, int>{};
    for (final r in rows) {
      final raw = (r['grp'] as String?) ?? '';
      final name = raw.isEmpty
          ? 'Other'
          : raw[0].toUpperCase() + raw.substring(1);
      out[name] = (out[name] ?? 0) + (r['sets'] as int);
    }
    final list = [for (final e in out.entries) (group: e.key, sets: e.value)]
      ..sort((a, b) => b.sets.compareTo(a.sets));
    return list;
  }

  /// Transactions (as raw rows) in [range], for the category breakdown.
  Future<List<Map<String, Object?>>> expenseRows(
    StatsRange range, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final db = await _db.getDatabase();
    return db.query(
      'expenses',
      where: "type != 'income' AND timestamp >= ? AND timestamp < ?",
      whereArgs: [
        bucketsFor(range, at).first.toIso8601String(),
        rangeEnd(range, at).toIso8601String(),
      ],
    );
  }
}
