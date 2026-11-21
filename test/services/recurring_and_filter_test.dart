import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/recurring_service.dart';
import 'package:trackit/utils/transaction_filter.dart';

void main() {
  group('advance', () {
    test('monthly keeps the anchor day and clamps short months', () {
      var d = DateTime(2026, 1, 31);
      d = advance(d, Frequency.monthly, 31);
      expect(d, DateTime(2026, 2, 28));
      d = advance(d, Frequency.monthly, 31);
      expect(d, DateTime(2026, 3, 31), reason: 'no drift after February');
    });

    test('weekly and yearly', () {
      expect(
        advance(DateTime(2026, 12, 28), Frequency.weekly, 1),
        DateTime(2027, 1, 4),
      );
      expect(
        advance(DateTime(2028, 2, 29), Frequency.yearly, 29),
        DateTime(2029, 2, 28),
      );
    });
  });

  group('recurring rules', () {
    late Database db;
    setUp(() async => db = await DatabaseService.openInMemoryForTesting());

    Expense rent(DateTime on) => Expense(
      amount: 15000,
      category: ExpenseCategory.other,
      timestamp: on,
      description: 'Rent',
      paymentMethod: PaymentMethod.upi,
    );

    test('a rule starts one period after the first entry', () {
      final r = RecurringRule.from(
        rent(DateTime(2026, 10, 31, 18)),
        Frequency.monthly,
      );
      expect(r.nextDate, DateTime(2026, 11, 30));
      expect(r.anchorDay, 31);
    });

    test('due entries are added once, catching up missed months', () async {
      final service = RecurringService();
      await service.save(
        RecurringRule.from(rent(DateTime(2026, 8, 5)), Frequency.monthly),
      );
      final added = await service.addDue(now: DateTime(2026, 11, 20));
      expect(added, 3); // 5 Sep, 5 Oct, 5 Nov
      expect(await service.addDue(now: DateTime(2026, 11, 20)), 0);

      final rows = await db.query('expenses', orderBy: 'timestamp');
      expect(rows.map((r) => r['timestamp']), [
        DateTime(2026, 9, 5, 9).toIso8601String(),
        DateTime(2026, 10, 5, 9).toIso8601String(),
        DateTime(2026, 11, 5, 9).toIso8601String(),
      ]);
      expect(rows.first['description'], 'Rent');
      expect(rows.first['payment_method'], 'upi');
      expect((await service.all()).single.nextDate, DateTime(2026, 12, 5));
    });

    test('paused rules add nothing', () async {
      final service = RecurringService();
      final rule = RecurringRule.from(
        rent(DateTime(2026, 10, 1)),
        Frequency.weekly,
      );
      await service.save(rule.copyWith(active: false));
      expect(await service.addDue(now: DateTime(2026, 11, 20)), 0);
      expect(await db.query('expenses'), isEmpty);
    });

    test('rules round-trip through the database', () async {
      final service = RecurringService();
      final rule = RecurringRule.from(
        Expense(
          amount: 80000,
          category: ExpenseCategory.other,
          timestamp: DateTime(2026, 11, 1),
          type: TxnType.income,
          categoryId: 'cat-salary',
        ),
        Frequency.monthly,
      );
      await service.save(rule);
      final back = (await service.all()).single;
      expect(back.isIncome, isTrue);
      expect(back.categoryId, 'cat-salary');
      expect(back.frequency, Frequency.monthly);
      await service.delete(back.id);
      expect(await service.all(), isEmpty);
    });
  });

  group('transaction filter', () {
    const food = Category(id: 'food', name: 'Food & Dining');
    const travel = Category(id: 'travel', name: 'Travel');
    final lunch = Expense(
      amount: 450,
      category: ExpenseCategory.food,
      timestamp: DateTime(2026, 11, 10, 13),
      description: 'Lunch with Sam',
      paymentMethod: PaymentMethod.upi,
    );
    final flight = Expense(
      amount: 6200.5,
      category: ExpenseCategory.transport,
      timestamp: DateTime(2026, 10, 2),
      description: 'Flight to Goa',
      paymentMethod: PaymentMethod.card,
    );
    final salary = Expense(
      amount: 80000,
      category: ExpenseCategory.other,
      timestamp: DateTime(2026, 11, 1),
      type: TxnType.income,
    );

    test('text matches note, category and amount, word by word', () {
      expect(
        const TransactionFilter(query: 'lunch sam').matches(lunch, food),
        isTrue,
      );
      expect(
        const TransactionFilter(query: 'dining').matches(lunch, food),
        isTrue,
      );
      expect(
        const TransactionFilter(query: '450').matches(lunch, food),
        isTrue,
      );
      expect(
        const TransactionFilter(query: '6200.50').matches(flight, travel),
        isTrue,
      );
      expect(
        const TransactionFilter(query: 'lunch goa').matches(lunch, food),
        isFalse,
      );
    });

    test('type, category, payment, dates and amounts narrow results', () {
      expect(
        const TransactionFilter(type: TxnType.income).matches(lunch, food),
        isFalse,
      );
      expect(
        const TransactionFilter(type: TxnType.income).matches(salary, food),
        isTrue,
      );
      expect(
        const TransactionFilter(categoryIds: {'travel'}).matches(lunch, food),
        isFalse,
      );
      expect(
        const TransactionFilter(
          paymentMethods: {PaymentMethod.card},
        ).matches(salary, food),
        isFalse,
        reason: 'no payment method never matches a payment filter',
      );
      final nov = TransactionFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 10),
      );
      expect(
        nov.matches(lunch, food),
        isTrue,
        reason: 'the end day is included',
      );
      expect(nov.matches(flight, travel), isFalse);
      expect(
        const TransactionFilter(minAmount: 500).matches(lunch, food),
        isFalse,
      );
      expect(
        const TransactionFilter(maxAmount: 500).matches(lunch, food),
        isTrue,
      );
    });

    test('active count and totals', () {
      final f = const TransactionFilter(
        query: 'x',
        type: TxnType.expense,
      ).copyWith(minAmount: () => 10, from: () => DateTime(2026));
      expect(f.activeCount, 3);
      expect(f.copyWith(type: () => null).activeCount, 2);
      final t = totalsOf([lunch, flight, salary]);
      expect(t.count, 3);
      expect(t.spent, 6650.5);
      expect(t.received, 80000);
    });
  });
}
