import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/models/workouts.dart';
import 'package:trackit/services/catalog_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/expense_service.dart';
import 'package:trackit/services/group_service.dart';
import 'package:trackit/services/id_generator.dart';
import 'package:trackit/services/workout_service.dart';

final _v4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Every id comes from IdGenerator, in one format per kind of row.
void main() {
  test('uuids are random v4 UUIDs', () {
    final ids = {for (var i = 0; i < 500; i++) IdGenerator.uuid()};
    expect(ids, hasLength(500));
    expect(ids.every(_v4.hasMatch), isTrue);
  });

  test('orNew keeps a server id and fills a missing one', () {
    expect(IdGenerator.orNew('abc'), 'abc');
    expect(IdGenerator.orNew(null), matches(_v4));
    expect(IdGenerator.orNew(''), matches(_v4));
  });

  test('subcategory ids follow the default pattern', () {
    final sub = defaultSubcategories.first;
    expect(sub.id, IdGenerator.subcategoryId(sub.categoryId, sub.name));
  });

  group('every insert path sets its own id', () {
    late Database db;

    setUp(() async {
      db = await DatabaseService.openInMemoryForTesting();
      // Drop the trigger safety net, so a missing id would show up as null.
      final triggers = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' "
        "AND name LIKE '%_identity'",
      );
      for (final t in triggers) {
        await db.execute('DROP TRIGGER ${t['name']}');
      }
    });

    Future<void> expectUuids(String table) async {
      final rows = await db.query(table, columns: ['uuid']);
      expect(rows, isNotEmpty, reason: table);
      for (final r in rows) {
        expect(r['uuid'], matches(_v4), reason: table);
      }
    }

    test('expenses', () async {
      await ExpenseService().addExpense(
        Expense(
          amount: 10,
          category: ExpenseCategory.food,
          timestamp: DateTime.now(),
        ),
      );
      await expectUuids('expenses');
    });

    test('workouts, exercises, sets and routines', () async {
      final service = WorkoutService();
      final workout = await service.addWorkout(
        Workout(type: WorkoutType.push, timestamp: DateTime.now()),
      );
      final exercise = await service.addExercise(
        Exercise(
          workoutId: workout.id!,
          name: 'Bench',
          muscleGroup: 'Chest',
          sets: [SetData(exerciseId: 0, setNumber: 1, weight: 60, reps: 8)],
        ),
      );
      await service.addSet(
        SetData(exerciseId: exercise.id!, setNumber: 2, weight: 60, reps: 8),
      );
      final routine = await service.addRoutine(
        Routine(
          name: 'Push',
          type: WorkoutType.push,
          exercises: [
            RoutineExercise(
              routineId: 0,
              name: 'Dips',
              muscleGroup: 'Triceps',
              setsCount: 2,
            ),
          ],
        ),
      );
      await service.startWorkoutFromRoutine(routine);

      for (final t in ['workouts', 'exercises', 'sets', 'routines']) {
        await expectUuids(t);
      }
    });

    test('groups, members, group expenses and settlements', () async {
      final service = GroupService();
      final group = await service.createGroup(
        name: 'Trip',
        icon: 'x',
        currentUserId: 0,
        currentUsername: 'Me',
      );
      await service.addMember(group.id!, 'ravi');
      final members = (await service.getGroup(group.id!)).members;
      await service.addGroupExpense(
        GroupExpense(
          groupId: group.id!,
          payerMemberId: members[0].id!,
          amount: 20,
          category: ExpenseCategory.food,
          timestamp: DateTime.now(),
          splits: [
            for (final m in members)
              ExpenseSplit(expenseId: 0, memberId: m.id!, shareAmount: 10),
          ],
        ),
      );
      await service.recordSettlement(
        Settlement(
          groupId: group.id!,
          fromMemberId: members[1].id!,
          toMemberId: members[0].id!,
          amount: 10,
          timestamp: DateTime.now(),
        ),
      );

      for (final t in [
        'groups',
        'group_members',
        'group_expenses',
        'settlements',
      ]) {
        await expectUuids(t);
      }
    });

    test('catalog rows use uuids, subcategories the shared key', () async {
      final catalog = CatalogService();
      final category = await catalog.addCategory(
        name: 'Pets',
        type: TxnType.expense,
      );
      final event = await catalog.addEvent(title: 'Goa');
      await catalog.setBudget(category.id, DateTime.now(), 500);
      final budget = await catalog.getBudget(category.id, DateTime.now());
      final sub = await catalog.addSubcategory(category.id, 'Food');

      expect(category.id, matches(_v4));
      expect(event.id, matches(_v4));
      expect(budget!.id, matches(_v4));
      expect(sub.id, '${category.id}:Food');
    });
  });
}
