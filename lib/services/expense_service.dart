import 'database_service.dart';
import 'api_service.dart';
import 'sync_service.dart';
import 'sync_outbox.dart';
import '../models/expenses.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseService {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();

  /// Add a new expense (Offline-first)
  Future<Expense> addExpense(Expense expense) async {
    final db = await _dbService.getDatabase();

    // 1. Save locally first
    final map = expense.toMap();
    map['is_synced'] = 0;
    final localId = await db.insert('expenses', map);

    // 2. Push in the background. Only the sync runner pushes rows: a direct
    // POST here could race a running sync and create a server duplicate.
    _syncService.performSync();

    return expense.copyWith(id: localId);
  }

  /// Get all expenses (from local cache)
  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query('expenses', orderBy: 'timestamp DESC');
    return maps.map((e) => Expense.fromMap(e)).toList();
  }

  /// Get expenses for a specific date
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    final db = await _dbService.getDatabase();
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();

    final maps = await db.query(
      'expenses',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => Expense.fromMap(e)).toList();
  }

  /// Get expenses for a specific month
  Future<List<Expense>> getExpensesByMonth(int year, int month) async {
    final db = await _dbService.getDatabase();
    final startOfMonth = DateTime(year, month, 1).toIso8601String();
    final endOfMonth = DateTime(
      year,
      month + 1,
      0,
      23,
      59,
      59,
    ).toIso8601String();

    final maps = await db.query(
      'expenses',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfMonth, endOfMonth],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => Expense.fromMap(e)).toList();
  }

  /// Get daily expense summary
  Future<DailyExpenseSummary> getDailySummary(DateTime date) async {
    final expenses = await getExpensesByDate(date);

    double totalAmount = 0.0;
    final categoryTotals = <ExpenseCategory, double>{};

    for (var category in ExpenseCategory.values) {
      categoryTotals[category] = 0.0;
    }

    for (var expense in expenses.where((e) => !e.isIncome)) {
      totalAmount += expense.amount;
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    return DailyExpenseSummary(
      date: DateTime(date.year, date.month, date.day),
      totalAmount: totalAmount,
      categoryTotals: categoryTotals,
    );
  }

  /// Get monthly total
  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await _dbService.getDatabase();
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM expenses "
      "WHERE type != 'income' AND timestamp >= ? AND timestamp < ?",
      [
        DateTime(year, month, 1).toIso8601String(),
        DateTime(year, month + 1, 1).toIso8601String(),
      ],
    );
    return (rows.first['total'] as num).toDouble();
  }

  /// Get last 7 days of expense totals (including today)
  Future<Map<DateTime, double>> getWeeklyExpenseData() async {
    final db = await _dbService.getDatabase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 6));

    final weeklyData = <DateTime, double>{
      for (int i = 0; i < 7; i++) startDate.add(Duration(days: i)): 0.0,
    };

    // Timestamps are local ISO strings, so the first 10 chars are the day.
    final rows = await db.rawQuery(
      "SELECT substr(timestamp, 1, 10) AS day, SUM(amount) AS total "
      "FROM expenses WHERE type != 'income' AND timestamp >= ? "
      "AND timestamp < ? GROUP BY day",
      [
        startDate.toIso8601String(),
        today.add(const Duration(days: 1)).toIso8601String(),
      ],
    );
    for (final row in rows) {
      final day = DateTime.tryParse(row['day'] as String);
      if (day == null || !weeklyData.containsKey(day)) continue;
      weeklyData[day] = (row['total'] as num).toDouble();
    }

    return weeklyData;
  }

  /// Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'expenses',
      expense.toMap()..['is_synced'] = 0,
      where: 'id = ?',
      whereArgs: [expense.id],
    );

    // Try to sync
    _syncService.performSync();
  }

  /// Delete an expense
  Future<void> deleteExpense(int id) async {
    final db = await _dbService.getDatabase();
    await db.transaction((txn) async {
      final expense = await txn.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [id],
      );

      // Already on the server: queue the delete so it replays when online.
      if (expense.isNotEmpty && expense.first['remote_id'] != null) {
        await SyncOutbox.enqueueDelete(
          txn,
          '${ApiService.transactionsPath}${expense.first['remote_id']}/',
        );
      }

      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
    _syncService.performSync();
  }

  Future<double> getMonthlyBudget() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['monthly_budget'],
    );
    if (maps.isNotEmpty) {
      return double.parse(maps.first['value'] as String);
    }
    return 50000;
  }

  Future<void> setMonthlyBudget(double amount) async {
    final db = await _dbService.getDatabase();
    await db.insert('settings', {
      'key': 'monthly_budget',
      'value': amount.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
