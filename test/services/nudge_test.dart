import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/nudge_lines.dart';
import 'package:trackit/services/nudge_service.dart';

void main() {
  final morning = DateTime(2026, 11, 23, 8); // a Monday, before the window

  group('lines', () {
    test('at least 100, all different, short enough for a notification', () {
      expect(nudgeLines.length, greaterThanOrEqualTo(100));
      expect(nudgeLines.map((l) => l.title).toSet().length, nudgeLines.length);
      for (final l in nudgeLines) {
        expect(l.title.length, lessThanOrEqualTo(40), reason: l.title);
        expect(l.body.length, lessThanOrEqualTo(60), reason: l.body);
      }
    });

    test('every time slot has lines to choose from', () {
      for (final s in NudgeSlot.values) {
        expect(nudgeLines.where((l) => l.slot == s), isNotEmpty, reason: '$s');
      }
    });
  });

  group('plan', () {
    test('one nudge a day inside the window, in the right slot', () {
      final plan = planNudges(now: morning, salt: 42);
      expect(plan, hasLength(14));
      for (final n in plan) {
        final minute = n.at.hour * 60 + n.at.minute;
        expect(minute, inInclusiveRange(600, 1170));
        final weekend =
            n.at.weekday == DateTime.saturday ||
            n.at.weekday == DateTime.sunday;
        expect(
          n.line.slot == slotFor(n.at) ||
              n.line.slot == NudgeSlot.any ||
              (weekend && n.line.slot == NudgeSlot.weekend),
          isTrue,
          reason: '${n.at} got a ${n.line.slot} line',
        );
      }
      expect(plan.map((n) => n.line.title).toSet(), hasLength(14));
    });

    test('planning again the same day gives the same nudges', () {
      final a = planNudges(now: morning, salt: 7);
      final b = planNudges(now: morning.add(const Duration(hours: 1)), salt: 7);
      expect(b.first.at, a.first.at);
      expect(b.first.line.title, a.first.line.title);
      final other = planNudges(now: morning, salt: 8);
      expect(
        other.map((n) => n.at).toList(),
        isNot(a.map((n) => n.at).toList()),
        reason: 'another install nudges at other times',
      );
    });

    test('today is skipped once logged, or when its time has passed', () {
      final skipped = planNudges(now: morning, salt: 42, skipToday: true);
      expect(skipped, hasLength(13));
      expect(skipped.first.at.day, 24);
      final late = planNudges(now: DateTime(2026, 11, 23, 21), salt: 42);
      expect(late.first.at.day, 24);
    });

    test('lines only repeat once a slot runs out', () {
      final few = [
        (slot: NudgeSlot.any, title: 'A', body: 'a'),
        (slot: NudgeSlot.any, title: 'B', body: 'b'),
      ];
      final plan = planNudges(now: morning, salt: 1, days: 4, lines: few);
      expect(plan.take(2).map((n) => n.line.title).toSet(), {'A', 'B'});
      expect(plan, hasLength(4));
    });
  });

  test('a spend today counts; tomorrow does not', () async {
    final db = await DatabaseService.openInMemoryForTesting();
    final s = NudgeService();
    expect(await s.spentToday(morning), isFalse);
    await db.insert(
      'expenses',
      Expense(
        amount: 40,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 11, 24, 9),
      ).toMap(),
    );
    expect(await s.spentToday(morning), isFalse);
    expect(await s.spentToday(DateTime(2026, 11, 24, 12)), isTrue);
  });
}
