import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/expenses.dart';
import '../services/catalog_service.dart';
import '../services/expense_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../utils/format.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  final CatalogService _catalog = CatalogService();

  List<Expense> _expenses = [];
  DailyExpenseSummary? _todaySummary;
  double _monthlySpent = 0;
  double _monthlyBudget = 50000;
  bool _isLoading = false;

  /// The month the Wallet is showing (first day), and its transactions.
  DateTime _selectedMonth = _firstOfMonth(DateTime.now());
  List<Expense> _monthExpenses = [];
  Map<String, Category> _categories = {};

  List<Expense> get expenses => _expenses;
  DailyExpenseSummary? get todaySummary => _todaySummary;
  double get monthlySpent => _monthlySpent;
  double get monthlyBudget => _monthlyBudget;
  bool get isLoading => _isLoading;
  DateTime get selectedMonth => _selectedMonth;
  List<Expense> get monthExpenses => _monthExpenses;

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);

  /// The category the user picked for [e]. Rows from before categories
  /// existed only have the legacy bucket; they map to its default.
  Category categoryOf(Expense e) =>
      _categories[e.categoryId] ??
      defaultCategories.firstWhere(
        (c) => c.legacy == e.category && c.type == e.type,
        orElse: () =>
            defaultCategories.firstWhere((c) => c.name == 'Miscellaneous'),
      );

  /// Spending (not income) per category, largest first.
  List<MapEntry<Category, double>> spendByCategory(Iterable<Expense> list) {
    final totals = <String, double>{};
    final byId = <String, Category>{};
    for (final e in list.where((e) => !e.isIncome)) {
      final c = categoryOf(e);
      byId[c.id] = c;
      totals[c.id] = (totals[c.id] ?? 0) + e.amount;
    }
    return [for (final id in totals.keys) MapEntry(byId[id]!, totals[id]!)]
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Show [month] in the Wallet.
  Future<void> selectMonth(DateTime month) async {
    _selectedMonth = _firstOfMonth(month);
    _monthExpenses = await _service.getExpensesByMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    notifyListeners();
  }

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
      _monthExpenses = await _service.getExpensesByMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      _categories = {for (final c in await _catalog.getCategories()) c.id: c};
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
            "You've exceeded your monthly budget of ${formatRupees(_monthlyBudget)}",
      );
    }
  }

  Future<void> updateExpense(Expense expense) async {
    await _service.updateExpense(expense);
    await _reload();
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
