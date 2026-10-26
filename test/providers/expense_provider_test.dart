import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/providers/expense_provider.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/utils/format.dart';
import 'package:trackit/widgets/analytics/spending_chart.dart';

/// The Wallet used to show only today's spending under "Monthly Spending",
/// and charts grouped by the six legacy buckets instead of the category
/// the user picked.
void main() {
  late Database db;
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1, 15);
  final food = defaultCategories.firstWhere((c) => c.name == 'Food & Dining');
  final travel = defaultCategories.firstWhere((c) => c.name == 'Travel');

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<void> add(
    double amount,
    DateTime at, {
    Category? category,
    ExpenseCategory legacy = ExpenseCategory.other,
    bool income = false,
  }) async {
    final map = Expense(
      amount: amount,
      category: category?.legacy ?? legacy,
      categoryId: category?.id,
      timestamp: at,
      type: income ? TxnType.income : TxnType.expense,
    ).toMap();
    map['is_synced'] = 0;
    await db.insert('expenses', map);
  }

  Future<ExpenseProvider> provider() async {
    final p = ExpenseProvider();
    await p.refreshData();
    return p;
  }

  test('the month view holds the whole month, not just today', () async {
    await add(100, thisMonth, category: food);
    await add(200, now, category: food);
    await add(999, lastMonth, category: food);

    final p = await provider();
    expect(p.monthExpenses.map((e) => e.amount), unorderedEquals([100, 200]));

    await p.selectMonth(lastMonth);
    expect(p.selectedMonth, DateTime(lastMonth.year, lastMonth.month));
    expect(p.monthExpenses.map((e) => e.amount), [999]);
  });

  test(
    'spending groups by the picked category, not the legacy bucket',
    () async {
      // Travel and Miscellaneous both fall in the legacy "other" bucket.
      await add(300, now, category: travel);
      await add(50, now, category: food);
      await add(40, now, legacy: ExpenseCategory.food); // pre-category row
      await add(5000, now, category: food, income: true);

      final p = await provider();
      final spend = p.spendByCategory(p.monthExpenses);

      expect(
        [for (final e in spend) (e.key.name, e.value)],
        [('Travel', 300.0), ('Food & Dining', 90.0)],
      );
    },
  );

  test('editing an expense updates the month view', () async {
    await add(100, now, category: food);
    final p = await provider();
    final original = p.monthExpenses.single;

    await p.updateExpense(
      Expense(
        id: original.id,
        amount: 160,
        category: travel.legacy,
        categoryId: travel.id,
        timestamp: original.timestamp,
      ),
    );

    expect(p.monthExpenses.single.amount, 160);
    expect(p.categoryOf(p.monthExpenses.single).name, 'Travel');
  });

  test('rupee amounts use Indian grouping', () {
    expect(formatRupees(1250), '₹1,250');
    expect(formatRupees(125000), '₹1,25,000');
    expect(formatRupees(99.5), '₹99.50');
    expect(formatRupeesCompact(950), '₹950');
    expect(formatRupeesCompact(1250), '₹1.3k');
    expect(formatRupeesCompact(250000), '₹2.5L');
  });

  test('chart gridlines use round steps', () {
    expect(niceInterval(1500), 500);
    expect(niceInterval(120), 50);
    expect(niceInterval(10), 5);
  });
}
