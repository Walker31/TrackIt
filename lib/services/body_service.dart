import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'database_service.dart';

typedef WeightEntry = ({DateTime date, double weight});

/// Body weight, one entry per day (a second entry the same day replaces
/// the first).
class BodyService {
  final DatabaseService _db = DatabaseService();

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> log(double weight, {DateTime? on}) async {
    final db = await _db.getDatabase();
    await db.insert('body_metrics', {
      'date': _day(on ?? DateTime.now()),
      'weight': weight,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(DateTime day) async {
    final db = await _db.getDatabase();
    await db.delete('body_metrics', where: 'date = ?', whereArgs: [_day(day)]);
  }

  /// Entries oldest first.
  Future<List<WeightEntry>> entries() async {
    final db = await _db.getDatabase();
    final rows = await db.query('body_metrics', orderBy: 'date ASC');
    return [
      for (final r in rows)
        (
          date: DateTime.parse(r['date'] as String),
          weight: (r['weight'] as num).toDouble(),
        ),
    ];
  }
}

/// Change over the last [days] days: latest minus the latest entry on or
/// before the window's start (or the first entry in the window).
double? weightChange(
  List<WeightEntry> entries, {
  int days = 30,
  DateTime? now,
}) {
  if (entries.length < 2) return null;
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day - days);
  // Records have no identity, so compare by position.
  var baseIndex = entries.lastIndexWhere((e) => !e.date.isAfter(start));
  if (baseIndex < 0) baseIndex = 0;
  if (baseIndex == entries.length - 1) return null;
  final base = entries[baseIndex];
  return entries.last.weight - base.weight;
}

/// A seven-entry moving average, smoothing daily water-weight noise.
List<WeightEntry> movingAverage(List<WeightEntry> entries, {int window = 7}) {
  final out = <WeightEntry>[];
  for (var i = 0; i < entries.length; i++) {
    final from = i - window + 1 < 0 ? 0 : i - window + 1;
    final slice = entries.sublist(from, i + 1);
    final avg = slice.fold<double>(0, (a, e) => a + e.weight) / slice.length;
    out.add((date: entries[i].date, weight: avg));
  }
  return out;
}
