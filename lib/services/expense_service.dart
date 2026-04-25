import 'package:sqflite/sqflite.dart';
import 'package:trackit/models/expenses.dart';
import 'database_service.dart';

/// Expense Service
/// Handles all expense-related database operations and calculations
class ExpenseService {
  final DatabaseService _dbService = DatabaseService();

  /// Add a new expense
  /// Returns the inserted expense with its ID
  Future<Expense> addExpense(Expense expense) async {
    final db = await _dbService.getDatabase();
    final id = await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return expense.copyWith(id: id as int?);
  }

  /// Get all expenses
  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbService.getDatabase();
    final maps = await db.query('expenses', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get expenses for a specific date
  /// Returns all expenses that occurred on the given date
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    final db = await _dbService.getDatabase();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final maps = await db.query(
      'expenses',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get expenses for a specific month
  /// Returns all expenses in the given month and year
  Future<List<Expense>> getExpensesByMonth(int year, int month) async {
    final db = await _dbService.getDatabase();
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final maps = await db.query(
      'expenses',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        startOfMonth.toIso8601String(),
        endOfMonth.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get expenses by category
  Future<List<Expense>> getExpensesByCategory(ExpenseCategory category) async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'expenses',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get daily expense summary
  /// Returns total amount and category-wise breakdown for a specific date
  Future<DailyExpenseSummary> getDailySummary(DateTime date) async {
    final expenses = await getExpensesByDate(date);

    double totalAmount = 0.0;
    final categoryTotals = <ExpenseCategory, double>{};

    // Initialize all categories with 0
    for (var category in ExpenseCategory.values) {
      categoryTotals[category] = 0.0;
    }

    // Calculate totals
    for (var expense in expenses) {
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

  /// Get monthly expense report
  /// Returns comprehensive monthly data including daily breakdowns
  Future<MonthlyExpenseReport> getMonthlyReport(int year, int month) async {
    final expenses = await getExpensesByMonth(year, month);

    double totalAmount = 0.0;
    final categoryTotals = <ExpenseCategory, double>{};
    final dailySummaries = <DailyExpenseSummary>[];

    // Initialize all categories with 0
    for (var category in ExpenseCategory.values) {
      categoryTotals[category] = 0.0;
    }

    // Group expenses by day
    final expensesByDay = <DateTime, List<Expense>>{};
    for (var expense in expenses) {
      final dateKey = DateTime(
        expense.timestamp.year,
        expense.timestamp.month,
        expense.timestamp.day,
      );
      if (!expensesByDay.containsKey(dateKey)) {
        expensesByDay[dateKey] = [];
      }
      expensesByDay[dateKey]!.add(expense);
    }

    // Create daily summaries
    for (var dateEntry in expensesByDay.entries) {
      double dayTotal = 0.0;
      final dayCategoryTotals = <ExpenseCategory, double>{};

      // Initialize daily categories
      for (var category in ExpenseCategory.values) {
        dayCategoryTotals[category] = 0.0;
      }

      for (var expense in dateEntry.value) {
        dayTotal += expense.amount;
        dayCategoryTotals[expense.category] =
            (dayCategoryTotals[expense.category] ?? 0.0) + expense.amount;
      }

      // Add daily totals to monthly totals
      totalAmount += dayTotal;
      dayCategoryTotals.forEach((category, amount) {
        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
      });

      dailySummaries.add(
        DailyExpenseSummary(
          date: dateEntry.key,
          totalAmount: dayTotal,
          categoryTotals: dayCategoryTotals,
        ),
      );
    }

    // Sort daily summaries by date
    dailySummaries.sort((a, b) => a.date.compareTo(b.date));

    return MonthlyExpenseReport(
      year: year,
      month: month,
      totalAmount: totalAmount,
      categoryTotals: categoryTotals,
      dailySummaries: dailySummaries,
    );
  }

  /// Get category-wise total for a specific date range
  Future<Map<ExpenseCategory, double>> getCategoryTotalsForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbService.getDatabase();
    final maps = await db.query(
      'expenses',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    final expenses = List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
    final categoryTotals = <ExpenseCategory, double>{};

    for (var category in ExpenseCategory.values) {
      categoryTotals[category] = 0.0;
    }

    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    return categoryTotals;
  }

  /// Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    final db = await _dbService.getDatabase();
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// Delete an expense
  Future<void> deleteExpense(int id) async {
    final db = await _dbService.getDatabase();
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get total expenses for a date range
  Future<double> getTotalForRange(DateTime startDate, DateTime endDate) async {
    final db = await _dbService.getDatabase();
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE timestamp >= ? AND timestamp <= ?',
      [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );
    return result[0]['total'] != null ? (result[0]['total'] as num).toDouble() : 0.0;
  }

  /// Get average daily spending for a month
  Future<double> getAverageDailySpending(int year, int month) async {
    final total = await getTotalForRange(
      DateTime(year, month, 1),
      DateTime(year, month + 1, 0),
    );
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return total / daysInMonth;
  }

  /// Get top spending categories for a date range
  Future<List<MapEntry<ExpenseCategory, double>>> getTopCategories({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 5,
  }) async {
    final categoryTotals =
        await getCategoryTotalsForRange(startDate, endDate);
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Get weekly expense summary
  Future<Map<DateTime, double>> getWeeklyExpenseData() async {
    final now = DateTime.now();
    final data = <DateTime, double>{};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final summary = await getDailySummary(date);
      data[DateTime(date.year, date.month, date.day)] = summary.totalAmount;
    }
    return data;
  }

  /// Get monthly budget from settings
  Future<double> getMonthlyBudget() async {
    final db = await _dbService.getDatabase();
    final result = await db.query('settings', where: 'key = ?', whereArgs: ['monthly_budget']);
    if (result.isNotEmpty) {
      return double.tryParse(result.first['value'] as String) ?? 50000;
    }
    return 50000;
  }

  /// Set monthly budget in settings
  Future<void> setMonthlyBudget(double amount) async {
    final db = await _dbService.getDatabase();
    await db.insert(
      'settings',
      {'key': 'monthly_budget', 'value': amount.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
