import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/expenses.dart';
import '../services/expense_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();

  List<Expense> _expenses = [];
  DailyExpenseSummary? _todaySummary;
  double _monthlySpent = 0;
  double _monthlyBudget = 50000;
  bool _isLoading = false;

  List<Expense> get expenses => _expenses;
  DailyExpenseSummary? get todaySummary => _todaySummary;
  double get monthlySpent => _monthlySpent;
  double get monthlyBudget => _monthlyBudget;
  bool get isLoading => _isLoading;

  ExpenseProvider() {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SyncService().performSync();
      final now = DateTime.now();
      _expenses = await _service.getExpensesByDate(now);
      _todaySummary = await _service.getDailySummary(now);
      _monthlySpent = await _service.getMonthlyTotal(now.year, now.month);
      _monthlyBudget = await _service.getMonthlyBudget();
    } catch (e) {
      debugPrint('Error refreshing expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    await _service.addExpense(expense);
    await refreshData();
    HapticFeedback.lightImpact();

    // Budget Alert
    if (_monthlySpent > _monthlyBudget) {
      NotificationService().showNotification(
        id: 100,
        title: "Budget Alert!",
        body:
            "You've exceeded your monthly budget of ₹${_monthlyBudget.toStringAsFixed(0)}",
      );
    }
  }

  Future<void> deleteExpense(int id) async {
    await _service.deleteExpense(id);
    await refreshData();
  }

  Future<void> updateBudget(double amount) async {
    await _service.setMonthlyBudget(amount);
    await refreshData();
  }

  Future<List<Expense>> getExpensesForDate(DateTime date) async {
    return await _service.getExpensesByDate(date);
  }

  Future<DailyExpenseSummary?> getSummaryForDate(DateTime date) async {
    return await _service.getDailySummary(date);
  }
}
