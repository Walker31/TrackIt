import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/budget_alert_service.dart';
import 'package:trackit/services/catalog_service.dart';
import 'package:trackit/services/database_service.dart';

/// Alerts at 80% and 100% of each budget, once per level per month, and
/// again only after spending drops back below a line.
void main() {
  late Database db;
  late List<BudgetAlert> sent;
  late BudgetAlertService alerts;
  final now = DateTime(2026, 10, 20, 12);
  final food = defaultCategories.firstWhere((c) => c.name == 'Food & Dining');

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
    sent = [];
    alerts = BudgetAlertService(notify: sent.add);
    await db.insert('settings', {
      'key': 'monthly_budget',
      'value': '10000',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<int> spend(double amount, {Category? category}) {
    final map = Expense(
      amount: amount,
      category: category?.legacy ?? ExpenseCategory.other,
      categoryId: category?.id,
      timestamp: now,
    ).toMap();
    map['is_synced'] = 0;
    return db.insert('expenses', map);
  }

  Future<List<String>> check() async =>
      [for (final a in await alerts.check(now: now)) a.title];

  test('levels', () {
    expect(BudgetAlertService.levelFor(7999, 10000), 0);
    expect(BudgetAlertService.levelFor(8000, 10000), 80);
    expect(BudgetAlertService.levelFor(10000, 10000), 100);
    expect(BudgetAlertService.levelFor(500, 0), 0);
  });

  test('warns at 80% once, then again when over', () async {
    await spend(7000);
    expect(await check(), isEmpty);

    await spend(1500); // 85%
    expect(await check(), ['85% of your monthly budget used']);
    expect(sent.single.body, contains('₹1,500 left'));

    await spend(500); // 90%: same level, no repeat
    expect(await check(), isEmpty);

    await spend(1200); // 102%
    expect(await check(), ['Over your monthly budget']);
    expect(await check(), isEmpty);
  });

  test('dropping back below a line lets it warn again', () async {
    final big = await spend(9000);
    expect(await check(), ['90% of your monthly budget used']);

    await db.delete('expenses', where: 'id = ?', whereArgs: [big]);
    expect(await check(), isEmpty);

    await spend(8500);
    expect(await check(), ['85% of your monthly budget used']);
  });

  test('category budgets warn on their own', () async {
    await CatalogService().setBudget(food.id, now, 2000);

    await spend(1700, category: food); // 85% of food, 17% overall
    expect(await check(), ['85% of your Food & Dining budget used']);

    await spend(400, category: food);
    expect(await check(), ['Over your Food & Dining budget']);
  });

  test('a new month starts fresh', () async {
    await spend(9000);
    expect(await check(), hasLength(1));

    final next = DateTime(2026, 11, 2);
    final map = Expense(
      amount: 9000,
      category: ExpenseCategory.other,
      timestamp: next,
    ).toMap();
    await db.insert('expenses', map);
    final titles = [for (final a in await alerts.check(now: next)) a.title];
    expect(titles, ['90% of your monthly budget used']);
  });
}
