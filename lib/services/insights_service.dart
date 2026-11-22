import 'package:intl/intl.dart';

import '../models/expenses.dart';
import '../utils/format.dart';
import 'database_service.dart';

enum InsightKind { money, training, mixed }

/// One observation about the user's own data, in plain words.
class Insight {
  final InsightKind kind;
  final String title;
  final String body;
  const Insight(this.kind, this.title, this.body);

  @override
  String toString() => '$title: $body';
}

/// One day of the look-back window: what was spent (and on food), and
/// whether a workout happened.
class DayFacts {
  final DateTime day;
  final double spent;
  final double food;
  final bool trained;
  const DayFacts(this.day, this.spent, this.food, this.trained);
}

/// Finds patterns that link spending and training. Each needs enough days
/// on both sides to mean something; otherwise it stays quiet.
List<Insight> findInsights(List<DayFacts> days, {int minDays = 4}) {
  final out = <Insight>[];
  final trained = days.where((d) => d.trained).toList();
  final rest = days.where((d) => !d.trained).toList();
  double avg(Iterable<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  if (trained.length >= minDays && rest.length >= minDays) {
    final onTrain = avg(trained.map((d) => d.spent));
    final onRest = avg(rest.map((d) => d.spent));
    if (onTrain > 0 && onRest > 0) {
      final diff = (onRest - onTrain) / onTrain;
      if (diff.abs() >= 0.15) {
        out.add(
          Insight(
            InsightKind.mixed,
            diff > 0
                ? 'You spend more on rest days'
                : 'You spend more on training days',
            'About ${formatRupees(diff > 0 ? onRest : onTrain)} a day, '
            'against ${formatRupees(diff > 0 ? onTrain : onRest)} on '
            '${diff > 0 ? 'days you train' : 'rest days'}.',
          ),
        );
      }
    }
    final foodTrain = avg(trained.map((d) => d.food));
    final foodRest = avg(rest.map((d) => d.food));
    if (foodRest > 0 && foodTrain >= 0 && foodRest - foodTrain >= 100) {
      out.add(
        Insight(
          InsightKind.mixed,
          'Food costs more on rest days',
          '${formatRupees(foodRest)} a day on food when you skip the gym, '
              '${formatRupees(foodTrain)} when you train.',
        ),
      );
    }
  }

  // Busiest spending weekday.
  if (days.length >= 14) {
    final byWeekday = <int, List<double>>{};
    for (final d in days) {
      byWeekday.putIfAbsent(d.day.weekday, () => []).add(d.spent);
    }
    final avgs = {for (final e in byWeekday.entries) e.key: avg(e.value)};
    final overall = avg(days.map((d) => d.spent));
    final top = avgs.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (overall > 0 && top.value >= overall * 1.5) {
      final name = DateFormat('EEEE').format(DateTime(2024, 1, top.key));
      out.add(
        Insight(
          InsightKind.money,
          '${name}s are your big spending day',
          'You spend ${formatRupees(top.value)} on an average $name, '
              '${(top.value / overall).toStringAsFixed(1)}× a typical day.',
        ),
      );
    }
  }

  // Training rhythm: last 7 days against the 3 weeks before.
  if (days.length >= 28) {
    final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));
    final lastWeek = sorted.sublist(sorted.length - 7).where((d) => d.trained);
    final before = sorted
        .sublist(sorted.length - 28, sorted.length - 7)
        .where((d) => d.trained)
        .length;
    final usual = before / 3;
    final now = lastWeek.length;
    if (usual >= 1 && now < usual - 0.9) {
      out.add(
        Insight(
          InsightKind.training,
          'Fewer workouts this week',
          '$now this week against your usual ${usual.toStringAsFixed(1)}. '
              'A short session still counts.',
        ),
      );
    } else if (now >= 2 && now > usual + 0.9) {
      out.add(
        Insight(
          InsightKind.training,
          'Your best week lately',
          '$now workouts in the last 7 days, up from about '
              '${usual.toStringAsFixed(1)} a week.',
        ),
      );
    }
  }
  return out;
}

class InsightsService {
  final DatabaseService _db = DatabaseService();

  /// Facts for the [days] days up to [now], then the insights they show.
  Future<List<Insight>> insights({int days = 42, DateTime? now}) async {
    final at = now ?? DateTime.now();
    final end = DateTime(at.year, at.month, at.day + 1);
    final start = DateTime(at.year, at.month, at.day - days + 1);
    final db = await _db.getDatabase();
    final spendRows = await db.rawQuery(
      '''
      SELECT substr(timestamp, 1, 10) AS day, category, category_id,
             SUM(amount) AS total
      FROM expenses
      WHERE type != 'income' AND timestamp >= ? AND timestamp < ?
      GROUP BY day, category, category_id
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final trainRows = await db.rawQuery(
      '''
      SELECT DISTINCT substr(w.timestamp, 1, 10) AS day
      FROM workouts w
      JOIN exercises e ON e.workout_id = w.id
      JOIN sets s ON s.exercise_id = e.id
      WHERE s.is_completed = 1 AND w.timestamp >= ? AND w.timestamp < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final foodIds = {
      for (final c in defaultCategories)
        if (c.legacy == ExpenseCategory.food) c.id,
    };
    final spent = <String, double>{};
    final food = <String, double>{};
    for (final r in spendRows) {
      final day = r['day'] as String;
      final total = (r['total'] as num).toDouble();
      spent[day] = (spent[day] ?? 0) + total;
      final isFood =
          foodIds.contains(r['category_id']) ||
          (r['category_id'] == null &&
              r['category'] == ExpenseCategory.food.name);
      if (isFood) food[day] = (food[day] ?? 0) + total;
    }
    final trained = {for (final r in trainRows) r['day'] as String};
    final facts = <DayFacts>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final key = DateFormat('yyyy-MM-dd').format(d);
      facts.add(
        DayFacts(d, spent[key] ?? 0, food[key] ?? 0, trained.contains(key)),
      );
    }
    // Days before the first record of anything aren't "rest days".
    final firstActive = facts.indexWhere((f) => f.spent > 0 || f.trained);
    if (firstActive < 0) return const [];
    return findInsights(facts.sublist(firstActive));
  }
}
