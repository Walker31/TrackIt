import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/expense_service.dart';

/// Weekly and monthly totals are computed in SQL instead of loading every
/// expense the user ever logged.
void main() {
  late Database db;
  final service = ExpenseService();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<void> add(double amount, DateTime at, {bool income = false}) async {
    final map = Expense(
      amount: amount,
      category: ExpenseCategory.food,
      timestamp: at,
      type: income ? TxnType.income : TxnType.expense,
    ).toMap();
    map['is_synced'] = 0;
    await db.insert('expenses', map);
  }

  test('weekly data sums each of the last 7 days, expenses only', () async {
    await add(100, today.add(const Duration(hours: 9)));
    await add(50, today.add(const Duration(hours: 23, minutes: 59)));
    await add(999, today.add(const Duration(hours: 12)), income: true);
    await add(30, today.subtract(const Duration(days: 6)));
    await add(70, today.subtract(const Duration(days: 7))); // too old

    final week = await service.getWeeklyExpenseData();

    expect(week.keys, hasLength(7));
    expect(week[today], 150.0);
    expect(week[today.subtract(const Duration(days: 6))], 30.0);
    expect(week.values.fold<double>(0, (a, b) => a + b), 180.0);
  });

  test('monthly total covers the whole month, expenses only', () async {
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 500);
    await add(10, first);
    await add(20, last); // used to fall outside the 23:59:59 bound
    await add(500, first, income: true);
    await add(40, first.subtract(const Duration(seconds: 1)));

    expect(await service.getMonthlyTotal(now.year, now.month), 30.0);
  });
}
