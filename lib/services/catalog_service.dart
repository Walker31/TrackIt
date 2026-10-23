import 'package:sqflite/sqflite.dart';
import '../models/expenses.dart';
import 'database_service.dart';

/// Local access to the blueprint's reference data: categories,
/// subcategories, events and per-category monthly budgets.
class CatalogService {
  final DatabaseService _dbService = DatabaseService();

  static String newId() {
    // RFC 4122 v4-shaped id without an extra dependency.
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = (now * 2654435761) & 0xFFFFFFFF;
    String h(int v, int n) => v.toRadixString(16).padLeft(n, '0');
    return '${h(now & 0xFFFFFFFF, 8)}-${h((now >> 32) & 0xFFFF, 4)}-4${h(r & 0xFFF, 3)}-a${h((r >> 12) & 0xFFF, 3)}-${h(now & 0xFFFFFFFFFFFF, 12)}';
  }

  Future<List<Category>> getCategories({TxnType? type}) async {
    final db = await _dbService.getDatabase();
    final rows = await db.query(
      'categories',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type.name],
      orderBy: 'is_default DESC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    final db = await _dbService.getDatabase();
    final rows = await db.query(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return rows.map(Subcategory.fromMap).toList();
  }

  Future<Category> addCategory({
    required String name,
    required TxnType type,
    String? icon,
    String? color,
  }) async {
    final db = await _dbService.getDatabase();
    final category = Category(
      id: newId(),
      userId: 'local',
      name: name,
      icon: icon ?? 'dots',
      color: color ?? '#5F5E5A',
      type: type,
    );
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<Subcategory> addSubcategory(String categoryId, String name) async {
    final db = await _dbService.getDatabase();
    final sub = Subcategory(id: newId(), categoryId: categoryId, name: name);
    await db.insert(
      'subcategories',
      sub.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return sub;
  }

  // ---- Events ----------------------------------------------------------

  Future<List<SpendEvent>> getEvents() async {
    final db = await _dbService.getDatabase();
    final rows = await db.query('events', orderBy: 'event_date DESC');
    return rows.map(SpendEvent.fromMap).toList();
  }

  Future<SpendEvent> addEvent({
    required String title,
    DateTime? eventDate,
    DateTime? endDate,
    String? description,
  }) async {
    final db = await _dbService.getDatabase();
    final event = SpendEvent(
      id: newId(),
      title: title,
      eventDate: eventDate ?? DateTime.now(),
      endDate: endDate,
      description: description,
    );
    await db.insert('events', event.toMap());
    return event;
  }

  /// Total spent and transaction count for an event.
  Future<({double total, int count})> getEventTotals(String eventId) async {
    final db = await _dbService.getDatabase();
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS n "
      "FROM expenses WHERE event_id = ? AND type = 'expense'",
      [eventId],
    );
    return (
      total: (rows.first['total'] as num).toDouble(),
      count: rows.first['n'] as int,
    );
  }

  // ---- Budgets ---------------------------------------------------------

  Future<Budget?> getBudget(String categoryId, DateTime month) async {
    final db = await _dbService.getDatabase();
    final rows = await db.query(
      'budgets',
      where: 'category_id = ? AND month = ?',
      whereArgs: [categoryId, dateOnly(DateTime(month.year, month.month, 1))],
    );
    return rows.isEmpty ? null : Budget.fromMap(rows.first);
  }

  Future<void> setBudget(
    String categoryId,
    DateTime month,
    double limitAmount,
  ) async {
    final db = await _dbService.getDatabase();
    final existing = await getBudget(categoryId, month);
    final budget = Budget(
      id: existing?.id ?? newId(),
      categoryId: categoryId,
      month: month,
      limitAmount: limitAmount,
    );
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Expense totals per category for an event.
  Future<Map<String, double>> getEventBreakdown(String eventId) async {
    final db = await _dbService.getDatabase();
    final rows = await db.rawQuery(
      "SELECT category_id, SUM(amount) AS total FROM expenses "
      "WHERE event_id = ? AND type = 'expense' AND category_id IS NOT NULL "
      "GROUP BY category_id ORDER BY total DESC",
      [eventId],
    );
    return {
      for (final r in rows)
        r['category_id'] as String: (r['total'] as num).toDouble(),
    };
  }

  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    final db = await _dbService.getDatabase();
    final rows = await db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [dateOnly(DateTime(month.year, month.month, 1))],
    );
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> deleteBudget(String budgetId) async {
    final db = await _dbService.getDatabase();
    await db.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);
  }

  /// Expense totals per category id for a calendar month.
  Future<Map<String, double>> getMonthlySpendByCategory(DateTime month) async {
    final db = await _dbService.getDatabase();
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end = DateTime(month.year, month.month + 1, 1).toIso8601String();
    final rows = await db.rawQuery(
      "SELECT category_id, SUM(amount) AS total FROM expenses "
      "WHERE type = 'expense' AND category_id IS NOT NULL "
      "AND timestamp >= ? AND timestamp < ? GROUP BY category_id",
      [start, end],
    );
    return {
      for (final r in rows)
        r['category_id'] as String: (r['total'] as num).toDouble(),
    };
  }
}
