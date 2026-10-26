import 'dart:async';
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

  StreamSubscription<void>? _syncSub;

  ExpenseProvider() {
    // Background syncs (started by writes) land after the screen has read
    // the database; reload whenever one completes.
    _syncSub = SyncService().onSyncComplete.listen((_) => _reload());
    refreshData();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  /// Show what's on the device straight away, then sync. Completes after
  /// the sync (for pull-to-refresh); [onSyncComplete] reloads the result.
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _reload(notify: false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await SyncService().performSync();
  }

  /// Re-read today's and this month's figures from the local database.
  Future<void> _reload({bool notify = true}) async {
    try {
      final now = DateTime.now();
      _expenses = await _service.getExpensesByDate(now);
      _todaySummary = await _service.getDailySummary(now);
      _monthlySpent = await _service.getMonthlyTotal(now.year, now.month);
      _monthlyBudget = await _service.getMonthlyBudget();
    } catch (e) {
      debugPrint('Error refreshing expenses: $e');
    }
    if (notify) notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    // The service starts a background sync; don't make the UI wait for it.
    await _service.addExpense(expense);
    await _reload();
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
    await _reload();
  }

  Future<void> updateBudget(double amount) async {
    await _service.setMonthlyBudget(amount);
    await _reload();
  }

  Future<List<Expense>> getExpensesForDate(DateTime date) async {
    return await _service.getExpensesByDate(date);
  }

  Future<DailyExpenseSummary?> getSummaryForDate(DateTime date) async {
    return await _service.getDailySummary(date);
  }
}
