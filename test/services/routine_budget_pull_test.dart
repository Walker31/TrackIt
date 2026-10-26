import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/models/workouts.dart';
import 'package:trackit/services/catalog_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/sync_service.dart';
import 'package:trackit/services/workout_service.dart';

/// Routines and budgets didn't sync at all before.
void main() {
  late Database db;
  final sync = SyncService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  group('routines', () {
    Map<String, dynamic> routine(
      int id, {
      String name = 'Push day',
      String? clientId,
      List<String> exercises = const ['Bench Press', 'Dips'],
      bool deleted = false,
    }) => {
      'id': id,
      'client_id': clientId ?? 'r-$id',
      'name': name,
      'type': 'push',
      'is_deleted': deleted,
      'routine_exercises': [
        for (final e in exercises)
          {'name': e, 'muscle_group': 'Chest', 'sets_count': 3},
      ],
    };

    Future<List<Routine>> routines() => WorkoutService().getAllRoutines();

    test('pulled routines arrive with their exercises', () async {
      await sync.mergeRemoteRoutines(db, [routine(1)]);
      final all = await routines();
      expect(all.single.name, 'Push day');
      expect(all.single.exercises.map((e) => e.name), ['Bench Press', 'Dips']);
    });

    test(
      'server edits replace a synced routine, not an unpushed one',
      () async {
        await sync.mergeRemoteRoutines(db, [routine(1), routine(2)]);
        await db.update('routines', {
          'name': 'Mine',
          'is_synced': 0,
        }, where: 'remote_id = 2');

        await sync.mergeRemoteRoutines(db, [
          routine(1, name: 'Chest', exercises: ['Flyes']),
          routine(2, name: 'Theirs'),
        ]);

        final byName = {for (final r in await routines()) r.name: r};
        expect(byName.keys, unorderedEquals(['Chest', 'Mine']));
        expect(byName['Chest']!.exercises.map((e) => e.name), ['Flyes']);
      },
    );

    test(
      'a routine we pushed is linked by client_id, not duplicated',
      () async {
        final local = await WorkoutService().addRoutine(
          Routine(
            name: 'Legs',
            type: WorkoutType.legs,
            exercises: [
              RoutineExercise(
                routineId: 0,
                name: 'Squat',
                muscleGroup: 'Legs',
                setsCount: 5,
              ),
            ],
          ),
        );
        final uuid =
            (await db.query(
                  'routines',
                  where: 'id = ?',
                  whereArgs: [local.id],
                )).single['uuid']
                as String;

        await sync.mergeRemoteRoutines(db, [routine(9, clientId: uuid)]);

        final rows = await db.query('routines');
        expect(rows.single['remote_id'], 9);
      },
    );

    test('tombstones delete the routine and its exercises', () async {
      await sync.mergeRemoteRoutines(db, [routine(1)]);
      await sync.mergeRemoteRoutines(db, [routine(1, deleted: true)]);
      expect(await db.query('routines'), isEmpty);
      expect(await db.query('routine_exercises'), isEmpty);
    });

    test('deleting a synced routine queues the server delete', () async {
      await sync.mergeRemoteRoutines(db, [routine(4)]);
      final id = (await db.query('routines')).single['id'] as int;

      await WorkoutService().deleteRoutine(id);

      expect(await db.query('routines'), isEmpty);
      final queued = await db.query('sync_outbox');
      expect(queued.single['path'], 'fitness/routines/4/');
    });
  });

  group('budgets', () {
    final food = defaultCategories.first.id;
    final transport = defaultCategories[1].id;
    final month = DateTime(2026, 10);

    Map<String, dynamic> budget(
      String id, {
      String? category,
      String limit = '5000.00',
      bool deleted = false,
    }) => {
      'id': id,
      'category': category ?? food,
      'month': '2026-10-01',
      'limit_amount': limit,
      'is_deleted': deleted,
    };

    Future<List<Map<String, Object?>>> rows() =>
        db.query('budgets', orderBy: 'id');

    test('pulled budgets are stored as synced', () async {
      await sync.mergeRemoteBudgets(db, [budget('b-1')]);
      final all = await rows();
      expect(all.single['limit_amount'], 5000.0);
      expect(all.single['is_synced'], 1);
      expect(
        (await CatalogService().getBudget(food, month))!.limitAmount,
        5000.0,
      );
    });

    test('a local edit not yet pushed wins over the pull', () async {
      await CatalogService().setBudget(food, month, 3000);

      await sync.mergeRemoteBudgets(db, [budget('b-1')]);

      final all = await rows();
      expect(all.single['limit_amount'], 3000.0);
      expect(all.single['is_synced'], 0);
    });

    test(
      'the server row for a slot replaces a synced one with another id',
      () async {
        await sync.mergeRemoteBudgets(db, [budget('b-1')]);
        await sync.mergeRemoteBudgets(db, [budget('b-2', limit: '8000')]);

        final all = await rows();
        expect(all.single['id'], 'b-2');
        expect(all.single['limit_amount'], 8000.0);
      },
    );

    test('tombstones delete synced budgets only', () async {
      await sync.mergeRemoteBudgets(db, [
        budget('b-1'),
        budget('b-2', category: transport),
      ]);
      await db.update('budgets', {'is_synced': 0}, where: "id = 'b-2'");

      await sync.mergeRemoteBudgets(db, [
        budget('b-1', deleted: true),
        budget('b-2', category: transport, deleted: true),
      ]);

      expect((await rows()).map((r) => r['id']), ['b-2']);
    });

    test('budgets for unknown categories are skipped', () async {
      await sync.mergeRemoteBudgets(db, [budget('b-1', category: 'missing')]);
      expect(await rows(), isEmpty);
    });

    test('setting a budget marks it for the next push', () async {
      await sync.mergeRemoteBudgets(db, [budget('b-1')]);
      await CatalogService().setBudget(food, month, 6500);

      final all = await rows();
      expect(all.single['id'], 'b-1', reason: 'keeps its id');
      expect(all.single['is_synced'], 0);
    });
  });

  test('new ids are random v4 UUIDs', () {
    final ids = {for (var i = 0; i < 500; i++) CatalogService.newId()};
    expect(ids, hasLength(500));
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(ids.every(v4.hasMatch), isTrue);
  });
}
