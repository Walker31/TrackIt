import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/insights_service.dart';

void main() {
  List<DayFacts> days(
    int n,
    DayFacts Function(int i, DateTime day) make, {
    DateTime? start,
  }) {
    final s = start ?? DateTime(2026, 10, 5); // a Monday
    return [
      for (var i = 0; i < n; i++) make(i, DateTime(s.year, s.month, s.day + i)),
    ];
  }

  test('more spending on rest days is reported', () {
    final facts = days(
      14,
      (i, d) => DayFacts(d, i.isEven ? 300 : 900, 0, i.isEven),
    );
    final found = findInsights(facts);
    expect(found.map((i) => i.title), contains('You spend more on rest days'));
  });

  test('small differences and thin data stay quiet', () {
    final close = days(
      14,
      (i, d) => DayFacts(d, i.isEven ? 500 : 540, 0, i.isEven),
    );
    expect(
      findInsights(close).where((i) => i.kind == InsightKind.mixed),
      isEmpty,
    );
    final thin = days(5, (i, d) => DayFacts(d, i == 0 ? 100 : 900, 0, i == 0));
    expect(findInsights(thin), isEmpty);
  });

  test('food on rest days', () {
    final facts = days(
      14,
      (i, d) => DayFacts(d, 600, i.isEven ? 100 : 450, i.isEven),
    );
    expect(
      findInsights(facts).map((i) => i.title),
      contains('Food costs more on rest days'),
    );
  });

  test('a standout weekday', () {
    final facts = days(
      21,
      (i, d) =>
          DayFacts(d, d.weekday == DateTime.saturday ? 3000 : 300, 0, false),
    );
    expect(
      findInsights(facts).map((i) => i.title),
      contains('Saturdays are your big spending day'),
    );
  });

  test('a slower training week', () {
    // Three weeks at four workouts a week, then one this week.
    final facts = days(28, (i, d) {
      final week = i ~/ 7, dow = i % 7;
      final trained = week < 3 ? dow < 4 : dow == 0;
      return DayFacts(d, 0, 0, trained);
    });
    expect(
      findInsights(facts).map((i) => i.title),
      contains('Fewer workouts this week'),
    );
  });

  test('reads spending and workouts from the database', () async {
    final db = await DatabaseService.openInMemoryForTesting();
    final now = DateTime(2026, 11, 21, 20);
    final food = defaultCategories.firstWhere(
      (c) => c.legacy == ExpenseCategory.food,
    );
    for (var i = 0; i < 14; i++) {
      final day = DateTime(2026, 11, 8 + i, 12);
      final trains = i.isEven;
      await db.insert(
        'expenses',
        Expense(
          amount: trains ? 200 : 800,
          category: food.legacy,
          categoryId: food.id,
          timestamp: day,
        ).toMap(),
      );
      if (trains) {
        final w = await db.insert('workouts', {
          'type': 'push',
          'timestamp': day.toIso8601String(),
          'is_synced': 0,
        });
        final e = await db.insert('exercises', {
          'workout_id': w,
          'name': 'Bench',
          'muscle_group': '',
          'is_synced': 0,
        });
        await db.insert('sets', {
          'exercise_id': e,
          'set_number': 1,
          'weight': 50,
          'reps': 5,
          'is_completed': 1,
          'is_synced': 0,
        });
      }
    }
    final found = await InsightsService().insights(now: now);
    final titles = found.map((i) => i.title);
    expect(titles, contains('You spend more on rest days'));
    expect(titles, contains('Food costs more on rest days'));
  });
}
