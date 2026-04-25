import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/expenses.dart';
import '../services/expense_service.dart';
import '../services/notification_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  
  List<Expense> _expenses = [];
  DailyExpenseSummary? _todaySummary;
  double _monthlyBudget = 50000;
  bool _isLoading = false;

  List<Expense> get expenses => _expenses;
  DailyExpenseSummary? get todaySummary => _todaySummary;
  double get monthlyBudget => _monthlyBudget;
  bool get isLoading => _isLoading;

  ExpenseProvider() {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      _expenses = await _service.getExpensesByDate(now);
      _todaySummary = await _service.getDailySummary(now);
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
    final dailyLimit = _monthlyBudget / 30;
    if (_todaySummary != null && _todaySummary!.totalAmount > dailyLimit) {
      NotificationService().showNotification(
        id: 100,
        title: "Budget Alert!",
        body: "You've exceeded your daily limit of ₹${dailyLimit.toStringAsFixed(0)}",
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
