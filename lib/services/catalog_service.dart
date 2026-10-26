import 'package:sqflite/sqflite.dart';
import '../models/expenses.dart';
import 'api_service.dart';
import 'app_mode_service.dart';
import 'database_service.dart';
import 'sync_outbox.dart';
import 'sync_service.dart';
import 'id_generator.dart';

/// Local access to the blueprint's reference data: categories,
/// subcategories, events and per-category monthly budgets.
class CatalogService {
  final DatabaseService _dbService = DatabaseService();

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
      id: IdGenerator.uuid(),
      userId: 'local',
      name: name,
      icon: icon ?? 'dots',
      color: color ?? '#5F5E5A',
      type: type,
    );
    await db.insert('categories', category.toMap());
    SyncService().performSync();
    return category;
  }

  Future<Subcategory> addSubcategory(String categoryId, String name) async {
    final db = await _dbService.getDatabase();
    final sub = Subcategory(
      id: IdGenerator.subcategoryId(categoryId, name),
      categoryId: categoryId,
      name: name,
    );
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
      id: IdGenerator.uuid(),
      title: title,
      eventDate: eventDate ?? DateTime.now(),
      endDate: endDate,
      description: description,
    );
    await db.insert('events', event.toMap());
    SyncService().performSync();
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
      id: existing?.id ?? IdGenerator.uuid(),
      categoryId: categoryId,
      month: month,
      limitAmount: limitAmount,
    );
    // Replacing resets is_synced to 0, so the next sync pushes it.
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    SyncService().performSync();
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
    await db.transaction((txn) async {
      // The server may have it even if a later edit isn't pushed yet; a
      // delete it doesn't know (404) is dropped from the queue.
      if (AppModeService.isServer) {
        await SyncOutbox.enqueueDelete(
          txn,
          '${ApiService.budgetsPath}$budgetId/',
        );
      }
      await txn.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);
    });
    SyncService().performSync();
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
