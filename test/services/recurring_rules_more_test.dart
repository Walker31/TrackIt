import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/recurring_service.dart';

void main() {
  late Database db;
  setUp(() async => db = await DatabaseService.openInMemoryForTesting());

  RecurringRule rule({
    required DateTime first,
    Frequency f = Frequency.monthly,
    DateTime? end,
    String? account,
  }) => RecurringRule.starting(
    first: first,
    frequency: f,
    amount: 999,
    type: TxnType.expense,
    category: ExpenseCategory.other,
    description: 'Netflix',
    endDate: end,
    accountId: account,
  );

  group('frequencies', () {
    test('every 2 weeks, 3 months and 6 months', () {
      expect(
        advance(DateTime(2026, 12, 25), Frequency.biweekly, 5),
        DateTime(2027, 1, 8),
      );
      expect(
        advance(DateTime(2026, 11, 30), Frequency.quarterly, 30),
        DateTime(2027, 2, 28),
      );
      expect(
        advance(DateTime(2027, 2, 28), Frequency.quarterly, 30),
        DateTime(2027, 5, 30),
        reason: 'back to the 30th after a short month',
      );
      expect(
        advance(DateTime(2026, 8, 31), Frequency.halfyearly, 31),
        DateTime(2027, 2, 28),
      );
    });

    test('the nth date, for "after N times"', () {
      expect(
        nthDate(DateTime(2026, 12, 5), Frequency.monthly, 12),
        DateTime(2027, 11, 5),
      );
      expect(
        nthDate(DateTime(2026, 12, 5), Frequency.monthly, 1),
        DateTime(2026, 12, 5),
      );
      expect(
        nthDate(DateTime(2026, 12, 1), Frequency.biweekly, 3),
        DateTime(2026, 12, 29),
      );
    });

    test('per year, for the monthly total', () {
      expect(Frequency.values.map((f) => f.perYear), [52, 26, 12, 4, 2, 1]);
      expect(Frequency.common, [
        Frequency.weekly,
        Frequency.monthly,
        Frequency.yearly,
      ]);
    });
  });

  group('rules made in the form', () {
    test('a future start adds nothing until its date', () async {
      final s = RecurringService();
      await s.save(rule(first: DateTime(2026, 12, 1)));
      expect(await s.addDue(now: DateTime(2026, 11, 23)), 0);
      expect(await db.query('expenses'), isEmpty);
      expect(await s.addDue(now: DateTime(2026, 12, 1)), 1);
      final r = (await s.all()).single;
      expect(r.nextDate, DateTime(2027, 1, 1));
    });

    test('a past start catches up; entries carry account and rule', () async {
      final s = RecurringService();
      final r = rule(first: DateTime(2026, 9, 10), account: 'acc-1');
      await s.save(r);
      expect(await s.addDue(now: DateTime(2026, 11, 23)), 3);
      final rows = await db.query('expenses', orderBy: 'timestamp');
      final e = rows.map(Expense.fromMap).toList();
      expect(e.map((x) => x.timestamp.month), [9, 10, 11]);
      expect(e.every((x) => x.accountId == 'acc-1'), isTrue);
      expect(e.every((x) => x.recurringId == r.id), isTrue);
    });

    test('an end date stops it and marks it done', () async {
      final s = RecurringService();
      final end = nthDate(DateTime(2026, 9, 1), Frequency.monthly, 2);
      await s.save(rule(first: DateTime(2026, 9, 1), end: end));
      expect(await s.addDue(now: DateTime(2026, 12, 15)), 2);
      final r = (await s.all()).single;
      expect(r.active, isFalse);
      expect(r.upcoming(3), isEmpty);
    });

    test(
      'an entry pulled from another device is marked as from the rule',
      () async {
        final s = RecurringService();
        final r = rule(first: DateTime(2026, 11, 1));
        await s.save(r);
        // The other device added November first; it arrives by sync.
        await db.insert('expenses', {
          ...r.expenseOn(DateTime(2026, 11, 1)).toMap(),
          'recurring_id': null,
          'uuid': r.entryUuid(DateTime(2026, 11, 1)),
          'is_synced': 1,
        });
        expect(await s.addDue(now: DateTime(2026, 11, 2)), 0);
        final row = (await db.query('expenses')).single;
        expect(row['recurring_id'], r.id);
      },
    );

    test('changing date or frequency moves the anchor; account kept', () async {
      final r = rule(first: DateTime(2026, 12, 31), account: 'acc-1');
      expect(r.anchorDay, 31);
      final weekly = r.copyWith(
        frequency: Frequency.weekly,
        nextDate: DateTime(2026, 12, 4), // a Friday
      );
      expect(weekly.anchorDay, DateTime.friday);
      expect(weekly.accountId, 'acc-1');
      final cleared = r.copyWith(
        accountId: () => null,
        endDate: () => DateTime(2027),
      );
      expect(cleared.accountId, isNull);
      expect(cleared.endDate, DateTime(2027));
      expect(cleared.anchorDay, 31, reason: 'date unchanged');
      expect(r.upcoming(3), [
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
      ]);
    });

    test('a rule keeps its account through the database', () async {
      final s = RecurringService();
      await s.save(rule(first: DateTime(2027), account: 'acc-9'));
      expect((await s.all()).single.accountId, 'acc-9');
    });
  });
}
