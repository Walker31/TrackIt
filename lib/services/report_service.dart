import 'package:flutter/material.dart';
import '../models/expenses.dart';
import 'catalog_service.dart';
import 'database_service.dart';

/// Spending in one category for the report.
class CategorySpend {
  final String name;
  final IconData icon;
  final Color color;
  final double amount;

  const CategorySpend(this.name, this.icon, this.color, this.amount);
}

/// One month at a glance: money in and out, the biggest categories and
/// how spending compares with the month before.
class MonthlyReport {
  final DateTime month;
  final double income;
  final double spent;
  final double previousSpent;

  /// Largest first; at most [ReportService.topCount].
  final List<CategorySpend> topCategories;

  const MonthlyReport({
    required this.month,
    required this.income,
    required this.spent,
    required this.previousSpent,
    required this.topCategories,
  });

  /// Income minus spending; negative when more went out than came in.
  double get net => income - spent;

  /// Change in spending from the previous month as a fraction (0.12 =
  /// 12% more), or null when there's nothing to compare with.
  double? get change =>
      previousSpent > 0 ? (spent - previousSpent) / previousSpent : null;

  bool get isEmpty => income == 0 && spent == 0;
}

class ReportService {
  ReportService({DatabaseService? database, CatalogService? catalog})
    : _db = database ?? DatabaseService(),
      _catalog = catalog ?? CatalogService();

  final DatabaseService _db;
  final CatalogService _catalog;

  static const topCount = 3;

  Future<MonthlyReport> monthly(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final previous = DateTime(month.year, month.month - 1);

    final (totals, previousTotals, byCategory, categories) = await (
      _totals(start, end),
      _totals(previous, start),
      _spendByCategory(start, end),
      _catalog.getCategories(),
    ).wait;
    final known = {for (final c in categories) c.id: c};

    final top = <CategorySpend>[
      for (final row in byCategory.take(topCount)) _describe(row, known),
    ];
    return MonthlyReport(
      month: start,
      income: totals.income,
      spent: totals.spent,
      previousSpent: previousTotals.spent,
      topCategories: top,
    );
  }

  Future<({double income, double spent})> _totals(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount END), 0) "
      'AS income, '
      "COALESCE(SUM(CASE WHEN type != 'income' THEN amount END), 0) "
      'AS spent '
      'FROM expenses WHERE timestamp >= ? AND timestamp < ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    final r = rows.first;
    return (
      income: (r['income'] as num).toDouble(),
      spent: (r['spent'] as num).toDouble(),
    );
  }

  /// Spending per category, largest first. Rows from before categories
  /// existed fall back to their legacy bucket.
  Future<List<Map<String, Object?>>> _spendByCategory(
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db.getDatabase();
    return db.rawQuery(
      'SELECT category_id, category, SUM(amount) AS total FROM expenses '
      "WHERE type != 'income' AND timestamp >= ? AND timestamp < ? "
      'GROUP BY COALESCE(category_id, category) ORDER BY total DESC',
      [from.toIso8601String(), to.toIso8601String()],
    );
  }

  CategorySpend _describe(
    Map<String, Object?> row,
    Map<String, Category> known,
  ) {
    final amount = (row['total'] as num).toDouble();
    final category = known[row['category_id']];
    if (category != null) {
      return CategorySpend(
        category.name,
        category.iconData,
        category.colorValue,
        amount,
      );
    }
    final legacy =
        ExpenseCategory.values
            .where((c) => c.name == row['category'])
            .firstOrNull ??
        ExpenseCategory.other;
    return CategorySpend(legacy.displayName, legacy.icon, legacy.color, amount);
  }
}
