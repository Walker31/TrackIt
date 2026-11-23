import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/money_service.dart';

void main() {
  late Database db;
  setUp(() async => db = await DatabaseService.openInMemoryForTesting());

  Future<void> txn(double amount, String? account, {bool income = false}) =>
      db.insert(
        'expenses',
        Expense(
          amount: amount,
          category: ExpenseCategory.food,
          timestamp: DateTime(2026, 11, 20),
          type: income ? TxnType.income : TxnType.expense,
          accountId: account,
        ).toMap(),
      );

  test('balances add income, subtract spending and follow transfers', () async {
    final s = AccountService();
    final bank = Account.create('HDFC', AccountKind.bank, 10000);
    final cash = Account.create('Cash', AccountKind.cash, 500);
    final card = Account.create('Amazon card', AccountKind.card, 0);
    for (final a in [bank, cash, card]) {
      await s.save(a);
    }
    await txn(80000, bank.id, income: true);
    await txn(1200, bank.id);
    await txn(300, cash.id);
    await txn(2500, card.id);
    await txn(999, null); // not tied to an account
    await s.transfer(from: bank.id, to: cash.id, amount: 2000);
    await s.transfer(from: bank.id, to: card.id, amount: 2500);

    final b = {for (final x in await s.balances()) x.account.name: x.balance};
    expect(b['HDFC'], 10000 + 80000 - 1200 - 2000 - 2500);
    expect(b['Cash'], 500 - 300 + 2000);
    expect(b['Amazon card'], 0, reason: 'bill paid off by the transfer');
  });

  test('archived accounts drop out; transfers need two accounts', () async {
    final s = AccountService();
    final a = Account.create('Old', AccountKind.bank, 100);
    final b = Account.create('New', AccountKind.bank, 0);
    await s.save(a);
    await s.save(b);
    await s.save(a.copyWith(archived: true));
    expect((await s.balances()).map((x) => x.account.name), ['New']);
    expect(await s.accounts(includeArchived: true), hasLength(2));
    expect(
      () => s.transfer(from: b.id, to: b.id, amount: 5),
      throwsArgumentError,
    );
  });

  test('the last used account is remembered', () async {
    final s = AccountService();
    final a = Account.create('A', AccountKind.bank, 0);
    final b = Account.create('B', AccountKind.cash, 0);
    await s.save(a);
    await s.save(b);
    expect(await s.lastUsed(), isNull);
    await txn(10, a.id);
    await txn(20, b.id);
    expect(await s.lastUsed(), b.id);
    await s.save(b.copyWith(archived: true));
    expect(await s.lastUsed(), a.id);
  });

  test('a transaction keeps its account through the database', () async {
    final a = Account.create('A', AccountKind.bank, 0);
    await AccountService().save(a);
    await txn(10, a.id);
    final row = (await db.query('expenses')).single;
    expect(Expense.fromMap(row).accountId, a.id);
  });

  group('goals', () {
    test('saved sums contributions, including money taken out', () async {
      final s = GoalService();
      final g = await s.create('Goa trip', 40000, by: DateTime(2027, 3, 1));
      await s.contribute(g.id, 10000);
      await s.contribute(g.id, 5000);
      await s.contribute(g.id, -2000);
      final back = (await s.goals()).single;
      expect(back.saved, 13000);
      expect(back.remaining, 27000);
      expect(back.progress, closeTo(0.325, 1e-9));
      expect(back.targetDate, DateTime(2027, 3, 1));
      await s.delete(g.id);
      expect(await s.goals(), isEmpty);
      expect(await db.query('goal_contributions'), isEmpty);
    });

    test('monthly amount needed counts this month', () {
      const g = Goal(id: 'g', name: 'x', target: 40000, saved: 13000);
      expect(monthlyNeeded(g), isNull, reason: 'no date');
      final dated = Goal(
        id: 'g',
        name: 'x',
        target: 40000,
        saved: 13000,
        targetDate: DateTime(2027, 3, 1),
      );
      // Nov, Dec, Jan, Feb, Mar: five months.
      expect(monthlyNeeded(dated, now: DateTime(2026, 11, 23)), 27000 / 5);
      expect(monthlyNeeded(dated, now: DateTime(2027, 4, 1)), isNull);
      final done = Goal(
        id: 'g',
        name: 'x',
        target: 100,
        saved: 150,
        targetDate: DateTime(2027),
      );
      expect(done.reached, isTrue);
      expect(done.progress, 1);
      expect(monthlyNeeded(done), isNull);
    });
  });
}
