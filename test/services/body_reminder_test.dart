import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/body_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/reminder_service.dart';
import 'package:trackit/utils/format.dart';

void main() {
  late Database db;
  setUp(() async => db = await DatabaseService.openInMemoryForTesting());

  group('body weight', () {
    test('one entry per day; the later one wins', () async {
      final s = BodyService();
      await s.log(80, on: DateTime(2026, 11, 1, 7));
      await s.log(79.6, on: DateTime(2026, 11, 1, 21));
      await s.log(79.2, on: DateTime(2026, 11, 5));
      final entries = await s.entries();
      expect(entries.map((e) => e.weight), [79.6, 79.2]);
      await s.delete(DateTime(2026, 11, 5));
      expect(await s.entries(), hasLength(1));
    });

    test('30-day change uses the last entry before the window', () {
      final entries = [
        (date: DateTime(2026, 9, 1), weight: 85.0),
        (date: DateTime(2026, 10, 20), weight: 82.0),
        (date: DateTime(2026, 11, 10), weight: 81.0),
        (date: DateTime(2026, 11, 20), weight: 80.0),
      ];
      expect(weightChange(entries, now: DateTime(2026, 11, 21)), -2.0);
      expect(
        weightChange(entries.sublist(2), now: DateTime(2026, 11, 21)),
        -1.0,
        reason: 'no entry before the window: start from the first in it',
      );
      expect(weightChange(entries.sublist(3)), isNull);
    });

    test('moving average smooths over the window', () {
      final entries = [
        for (var i = 0; i < 4; i++)
          (date: DateTime(2026, 11, i + 1), weight: 80.0 + i),
      ];
      final avg = movingAverage(entries, window: 2);
      expect(avg.map((e) => e.weight), [80, 80.5, 81.5, 82.5]);
    });
  });

  test('daily allowance spreads what was left this morning', () {
    // 30-day month, day 21: 10 days left including today.
    final left = leftToSpendToday(
      budget: 30000,
      spentThisMonth: 20500,
      spentToday: 500,
      now: DateTime(2026, 11, 21),
    );
    expect(left, (30000 - 20000) / 10 - 500);
    expect(
      leftToSpendToday(
        budget: 1000,
        spentThisMonth: 1200,
        spentToday: 300,
        now: DateTime(2026, 11, 30),
      ),
      lessThan(0),
    );
  });

  test('a day counts as logged with an expense or a completed set', () async {
    final day = DateTime(2026, 11, 21, 12);
    final r = ReminderService();
    expect(await r.loggedOn(day), isFalse);

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
      'is_completed': 0,
      'is_synced': 0,
    });
    expect(await r.loggedOn(day), isFalse, reason: 'planned sets do not count');
    await db.update('sets', {'is_completed': 1});
    expect(await r.loggedOn(day), isTrue);

    await db.insert(
      'expenses',
      Expense(
        amount: 10,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 11, 22, 9),
      ).toMap(),
    );
    expect(await r.loggedOn(DateTime(2026, 11, 22)), isTrue);
  });

  test('reminder time and switch persist', () async {
    final r = ReminderService();
    expect(await r.time(), (20, 0));
    expect(await r.enabled(), isTrue);
    await r.setTime(7, 30);
    await r.setEnabled(false);
    expect(await r.time(), (7, 30));
    expect(await r.enabled(), isFalse);
  });
}
