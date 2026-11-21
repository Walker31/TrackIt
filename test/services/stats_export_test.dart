import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/export_service.dart';
import 'package:trackit/services/stats_service.dart';

void main() {
  late Database db;
  final now = DateTime(2026, 11, 21, 15);

  setUp(() async => db = await DatabaseService.openInMemoryForTesting());

  Future<void> spend(
    double amount,
    DateTime at, {
    bool income = false,
    String? note,
  }) => db.insert(
    'expenses',
    Expense(
      amount: amount,
      category: ExpenseCategory.food,
      timestamp: at,
      description: note,
      type: income ? TxnType.income : TxnType.expense,
    ).toMap(),
  );

  Future<void> lift(
    DateTime at,
    String muscle,
    List<(double, int, bool)> sets,
  ) async {
    final w = await db.insert('workouts', {
      'type': 'pull',
      'timestamp': at.toIso8601String(),
      'is_synced': 0,
    });
    final e = await db.insert('exercises', {
      'workout_id': w,
      'name': 'Row',
      'muscle_group': muscle,
      'is_synced': 0,
    });
    for (var i = 0; i < sets.length; i++) {
      await db.insert('sets', {
        'exercise_id': e,
        'set_number': i + 1,
        'weight': sets[i].$1,
        'reps': sets[i].$2,
        'is_completed': sets[i].$3 ? 1 : 0,
        'is_synced': 0,
      });
    }
  }

  group('ranges', () {
    test('buckets end today; a year is twelve months', () {
      final week = bucketsFor(StatsRange.week, now);
      expect(week, hasLength(7));
      expect(week.first, DateTime(2026, 11, 15));
      expect(week.last, DateTime(2026, 11, 21));
      expect(bucketsFor(StatsRange.month, now), hasLength(30));
      final year = bucketsFor(StatsRange.year, now);
      expect(year.first, DateTime(2025, 12));
      expect(year.last, DateTime(2026, 11));
    });

    test('spending sums per day and leaves income out', () async {
      await spend(100, DateTime(2026, 11, 21, 9));
      await spend(50, DateTime(2026, 11, 21, 20));
      await spend(999, DateTime(2026, 11, 21, 10), income: true);
      await spend(70, DateTime(2026, 11, 14)); // just outside the week
      final week = await StatsService().spending(StatsRange.week, now: now);
      expect(week.last.value, 150);
      expect(week.fold<double>(0, (a, p) => a + p.value), 150);
    });

    test('a year groups by month', () async {
      await spend(100, DateTime(2026, 11, 2));
      await spend(200, DateTime(2026, 11, 20));
      await spend(300, DateTime(2026, 1, 5));
      final year = await StatsService().spending(StatsRange.year, now: now);
      expect(year.last.value, 300);
      expect(year.firstWhere((p) => p.start == DateTime(2026, 1)).value, 300);
    });

    test('volume and muscle sets count completed sets only', () async {
      await lift(DateTime(2026, 11, 20), 'Back', [
        (50, 10, true),
        (50, 8, false),
      ]);
      await lift(DateTime(2026, 11, 19), 'back ', [(40, 10, true)]);
      await lift(DateTime(2026, 11, 18), '', [(20, 10, true)]);
      final volume = await StatsService().volume(StatsRange.week, now: now);
      expect(volume.fold<double>(0, (a, p) => a + p.value), 500 + 400 + 200);
      final muscles = await StatsService().muscleSets(
        StatsRange.week,
        now: now,
      );
      expect(muscles, [(group: 'Back', sets: 2), (group: 'Other', sets: 1)]);
    });
  });

  group('csv', () {
    test('fields are quoted and formulas neutralised', () {
      expect(csvField('plain'), 'plain');
      expect(csvField('a, b'), '"a, b"');
      expect(csvField('say "hi"'), '"say ""hi"""');
      expect(csvField('=SUM(A1)'), "'=SUM(A1)");
      expect(csvField('-50'), '-50', reason: 'negative numbers stay numbers');
      expect(csvField(null), '');
    });

    test('transactions export has a header and one row each', () async {
      await spend(120.5, DateTime(2026, 11, 3, 8, 5), note: 'Tea, snacks');
      await spend(80000, DateTime(2026, 11, 1), income: true);
      final lines = (await ExportService().transactionsCsv()).trim().split(
        '\n',
      );
      expect(lines.first, startsWith('Date,Time,Type,Amount,Category'));
      expect(lines, hasLength(3));
      expect(lines[1], startsWith('2026-11-01,00:00,Income,80000.00'));
      expect(lines[2], contains('120.50'));
      expect(lines[2], contains('"Tea, snacks"'));
    });

    test('workouts export has one row per set', () async {
      await lift(DateTime(2026, 11, 20), 'Back', [
        (50, 10, true),
        (50, 8, false),
      ]);
      final lines = (await ExportService().workoutsCsv()).trim().split('\n');
      expect(lines, hasLength(3));
      expect(lines[1], '2026-11-20,Pull,Row,Back,1,50.0,10,Yes,');
      expect(lines[2], endsWith(',No,'));
    });
  });
}
