import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/format.dart';
import 'catalog_service.dart';
import 'database_service.dart';
import 'expense_service.dart';
import 'notification_service.dart';

/// One notification to show.
class BudgetAlert {
  final int notificationId;
  final String title;
  final String body;

  const BudgetAlert(this.notificationId, this.title, this.body);

  @override
  String toString() => '$title: $body';
}

/// Warns at 80% and again at 100% of the monthly budget and of each
/// category budget, once per level per month.
///
/// The level last reached is stored per budget and month, so a warning
/// isn't repeated on every new expense; if spending drops back (an expense
/// deleted or edited down), crossing the line again warns again.
class BudgetAlertService {
  BudgetAlertService({
    DatabaseService? database,
    ExpenseService? expenses,
    CatalogService? catalog,
    void Function(BudgetAlert alert)? notify,
  }) : _db = database ?? DatabaseService(),
       _expenses = expenses ?? ExpenseService(),
       _catalog = catalog ?? CatalogService(),
       _notify = notify ?? _showNotification;

  final DatabaseService _db;
  final ExpenseService _expenses;
  final CatalogService _catalog;
  final void Function(BudgetAlert alert) _notify;

  static const warnAt = 0.8;
  static const _overallId = 100;

  static void _showNotification(BudgetAlert a) => NotificationService()
      .showNotification(id: a.notificationId, title: a.title, body: a.body);

  /// 0 below 80%, 80 from 80%, 100 at or over the limit.
  static int levelFor(double spent, double limit) {
    if (limit <= 0) return 0;
    if (spent >= limit) return 100;
    if (spent >= limit * warnAt) return 80;
    return 0;
  }

  /// Compare this month's spending with every budget and send any new
  /// alerts. Returns what was sent.
  Future<List<BudgetAlert>> check({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final month = DateTime(today.year, today.month);
    final monthKey = DateFormat('yyyy-MM').format(month);

    final (spent, overallLimit, byCategory, budgets, categories) = await (
      _expenses.getMonthlyTotal(month.year, month.month),
      _expenses.getMonthlyBudget(),
      _catalog.getMonthlySpendByCategory(month),
      _catalog.getBudgetsForMonth(month),
      _catalog.getCategories(),
    ).wait;
    final names = {for (final c in categories) c.id: c.name};

    final alerts = <BudgetAlert>[];
    final overall = await _crossed('overall_$monthKey', spent, overallLimit);
    if (overall != 0) {
      alerts.add(
        _alert(_overallId, 'monthly budget', spent, overallLimit, overall),
      );
    }
    for (final b in budgets) {
      final catSpent = byCategory[b.categoryId] ?? 0;
      final level = await _crossed(
        'cat_${b.categoryId}_$monthKey',
        catSpent,
        b.limitAmount,
      );
      if (level == 0) continue;
      final name = names[b.categoryId] ?? 'category';
      alerts.add(
        _alert(
          1000 + (b.categoryId.hashCode & 0xfff),
          '$name budget',
          catSpent,
          b.limitAmount,
          level,
        ),
      );
    }
    alerts.forEach(_notify);
    return alerts;
  }

  /// Store the level [spent] has reached for [scope]; returns it if it's
  /// higher than last time (a line was just crossed), else 0.
  Future<int> _crossed(String scope, double spent, double limit) async {
    final db = await _db.getDatabase();
    final key = 'budget_alert_$scope';
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    final before = rows.isEmpty
        ? 0
        : int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
    final now = levelFor(spent, limit);
    if (now != before) {
      await db.insert('settings', {
        'key': key,
        'value': '$now',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return now > before ? now : 0;
  }

  static BudgetAlert _alert(
    int id,
    String what,
    double spent,
    double limit,
    int level,
  ) {
    final amounts = '${formatRupees(spent)} of ${formatRupees(limit)}';
    if (level >= 100) {
      return BudgetAlert(
        id,
        'Over your $what',
        "You've spent $amounts this month.",
      );
    }
    final percent = (spent / limit * 100).floor();
    return BudgetAlert(
      id,
      '$percent% of your $what used',
      "You've spent $amounts. ${formatRupees(limit - spent)} left this month.",
    );
  }
}
