import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/report_service.dart';

void main() {
  late Database db;
  final oct = DateTime(2026, 10, 10);
  final sep = DateTime(2026, 9, 10);
  Category cat(String name) => defaultCategories.firstWhere((c) => c.name == name);

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
    await db.insert(
      'expenses',
      Expense(
        amount: amount,
        category: category?.legacy ?? legacy,
        categoryId: category?.id,
        timestamp: at,
        type: income ? TxnType.income : TxnType.expense,
      ).toMap(),
    );
  }

  test('income, spending, change and top categories', () async {
    await add(50000, oct, income: true);
    await add(3000, oct, category: cat('Food & Dining'));
    await add(1000, oct, category: cat('Food & Dining'));
    await add(2500, oct, category: cat('Travel'));
    await add(500, oct, category: cat('Shopping'));
    await add(200, oct, legacy: ExpenseCategory.transport); // pre-categories
    await add(6000, sep, category: cat('Travel'));

    final r = await ReportService().monthly(oct);

    expect(r.income, 50000);
    expect(r.spent, 7200);
    expect(r.net, 42800);
    expect(r.previousSpent, 6000);
    expect(r.change, closeTo(0.2, 1e-9));
    expect([for (final c in r.topCategories) c.name], [
      'Food & Dining',
      'Travel',
      'Shopping',
    ]);
    expect(r.topCategories.first.amount, 4000);
  });

  test('no previous spending means no comparison', () async {
    await add(800, oct, category: cat('Travel'));
    final r = await ReportService().monthly(oct);
    expect(r.change, isNull);
    expect(r.isEmpty, isFalse);
  });

  test('an empty month', () async {
    final r = await ReportService().monthly(oct);
    expect(r.isEmpty, isTrue);
    expect(r.topCategories, isEmpty);
  });
}
