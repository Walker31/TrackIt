import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/workouts.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/progress_service.dart';
import 'package:trackit/services/workout_service.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  /// A workout on [day] with one exercise and the given (weight, reps, done).
  Future<int> log(
    DateTime day,
    String name,
    List<(double, int, bool)> sets, {
    String muscle = '',
  }) async {
    final w = await db.insert('workouts', {
      'type': 'push',
      'timestamp': day.toIso8601String(),
      'is_synced': 0,
    });
    final e = await db.insert('exercises', {
      'workout_id': w,
      'name': name,
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
    return w;
  }

  group('maths', () {
    test('estimated one-rep max', () {
      expect(estimatedOneRepMax(100, 1), 100);
      expect(estimatedOneRepMax(100, 10), closeTo(133.33, 0.01));
      expect(estimatedOneRepMax(0, 10), 0);
      expect(estimatedOneRepMax(50, 0), 0);
    });

    ExerciseSession session(List<(double, int)> sets) => ExerciseSession(
      workoutId: 1,
      date: DateTime(2026, 11, 1),
      sets: [for (final s in sets) LoggedSet(s.$1, s.$2)],
    );

    test('adds weight when every top set kept its reps', () {
      final t = suggestNext(session([(60, 8), (60, 8), (60, 8)]))!;
      expect(t.increase, isTrue);
      expect(t.weight, 62.5);
      expect(t.reps, 8);
    });

    test('repeats the weight for one more rep when reps dropped', () {
      final t = suggestNext(session([(60, 8), (60, 7), (60, 6)]))!;
      expect(t.increase, isFalse);
      expect(t.weight, 60);
      expect(t.reps, 9);
    });

    test('warm-up sets below the top weight are ignored', () {
      final t = suggestNext(session([(20, 10), (60, 5), (60, 5)]))!;
      expect(t.weight, 62.5);
      expect(t.reps, 5);
    });

    test('bodyweight work chases reps; nothing without history', () {
      final t = suggestNext(session([(0, 12), (0, 10)]))!;
      expect(t.weight, 0);
      expect(t.reps, 13);
      expect(suggestNext(null), isNull);
    });

    test('new records need a previous session', () {
      expect(newRecords(const LoggedSet(100, 5), null), isEmpty);
      final prev = ExerciseRecords.from('Bench', '', [
        session([(80, 5)]),
      ]);
      expect(newRecords(const LoggedSet(85, 1), prev), {RecordKind.weight});
      expect(newRecords(const LoggedSet(80, 8), prev), {RecordKind.oneRepMax});
      expect(newRecords(const LoggedSet(70, 5), prev), isEmpty);
    });

    test('streak counts back from today, or from yesterday', () {
      final now = DateTime(2026, 11, 21, 9);
      expect(countStreak({'2026-11-21', '2026-11-20', '2026-11-19'}, now), 3);
      expect(countStreak({'2026-11-20', '2026-11-19'}, now), 2);
      expect(countStreak({'2026-11-19'}, now), 0);
      expect(
        countStreak({'2026-11-01', '2026-10-31'}, DateTime(2026, 11, 1)),
        2,
      );
    });
  });

  group('queries', () {
    test(
      'sessions group by workout, newest first, completed sets only',
      () async {
        await log(DateTime(2026, 11, 1), 'Bench Press', [
          (60, 8, true),
          (60, 8, true),
        ]);
        final today = await log(DateTime(2026, 11, 5), ' bench press ', [
          (62.5, 8, true),
          (62.5, 0, false),
        ]);
        await log(DateTime(2026, 11, 3), 'Squat', [(100, 5, true)]);

        final all = await ProgressService().sessionsFor('Bench Press');
        expect(all.map((s) => s.sets.length), [1, 2]);
        expect(all.first.topSet.weight, 62.5);

        final last = await ProgressService().lastSession(
          'Bench Press',
          excludeWorkoutId: today,
        );
        expect(last!.date, DateTime(2026, 11, 1));
        expect(last.sets.map((s) => s.reps), [8, 8]);
      },
    );

    test(
      'records across exercises keep a muscle group and sort by recency',
      () async {
        await log(DateTime(2026, 11, 1), 'Squat', [
          (100, 5, true),
        ], muscle: 'Quads');
        await log(DateTime(2026, 11, 4), 'squat', [
          (105, 3, true),
          (90, 8, true),
        ]);
        await log(DateTime(2026, 11, 2), 'Bench Press', [(60, 8, true)]);
        await log(DateTime(2026, 11, 6), 'Curl', [
          (10, 10, false),
        ]); // never done

        final records = await ProgressService().allRecords();
        expect(records.map((r) => r.name), ['squat', 'Bench Press']);
        final squat = records.first;
        expect(squat.muscleGroup, 'Quads');
        expect(squat.bestWeight, 105);
        expect(squat.repsAtBestWeight, 3);
        expect(squat.sessions, 2);
        expect(squat.bestSessionVolume, 105 * 3 + 90 * 8);
      },
    );

    test('history skips empty workouts and loads children', () async {
      await db.insert('workouts', {
        'type': 'push',
        'timestamp': DateTime(2026, 11, 7).toIso8601String(),
        'is_synced': 0,
      });
      await log(DateTime(2026, 11, 1), 'Row', [(50, 10, true)]);
      final history = await ProgressService().history();
      expect(history, hasLength(1));
      expect(history.single.exercises.single.sets.single.weight, 50);
    });

    test('streak only counts days with a completed set', () async {
      final now = DateTime.now();
      await log(now, 'Row', [(50, 10, true)]);
      await log(now.subtract(const Duration(days: 1)), 'Row', [
        (50, 10, false),
      ]);
      expect(await ProgressService().streak(now: now), 1);
    });

    test(
      'deleting a set renumbers the rest and marks the workout dirty',
      () async {
        final w = await log(DateTime(2026, 11, 1), 'Row', [
          (50, 10, true),
          (55, 8, true),
          (60, 6, true),
        ]);
        await db.update('workouts', {'is_synced': 1});
        final ids = (await db.query(
          'sets',
          orderBy: 'set_number',
        )).map((r) => r['id'] as int);
        await WorkoutService().deleteSet(ids.first);
        final rest = await db.query('sets', orderBy: 'set_number');
        expect(rest.map((r) => (r['set_number'], r['weight'])), [
          (1, 55.0),
          (2, 60.0),
        ]);
        final workout = await db.query(
          'workouts',
          where: 'id = ?',
          whereArgs: [w],
        );
        expect(workout.single['is_synced'], 0);
      },
    );
  });

  group('exercise library', () {
    test('prefix matches rank first and own exercises come first', () {
      final results = searchExercises('bench');
      expect(results.first.name, 'Bench Press');
      expect(results.map((e) => e.name), contains('Close-Grip Bench Press'));

      final mine = searchExercises(
        'bench',
        extra: const [
          LibraryExercise('Bench Press', 'Chest'),
          LibraryExercise('Bench Dip', ''),
        ],
      );
      expect(mine.where((e) => e.name == 'Bench Press'), hasLength(1));
      expect(mine.take(2).map((e) => e.name), ['Bench Press', 'Bench Dip']);
    });

    test('muscle group search and lookup', () {
      expect(searchExercises('calves').map((e) => e.muscleGroup).toSet(), {
        'Calves',
      });
      expect(muscleGroupFor(' squat '), 'Quads');
      expect(muscleGroupFor('Unknown Lift'), isNull);
    });
  });
}
