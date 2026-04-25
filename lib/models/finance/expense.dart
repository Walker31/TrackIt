import 'expense_category.dart';

class Expense {
  final int? id;
  final double amount;
  final ExpenseCategory category;
  final DateTime timestamp;
  final String? description;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.timestamp,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      category: ExpenseCategory.fromString(map['category'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String?,
    );
  }
}

class DailyExpenseSummary {
  final DateTime date;
  final double totalAmount;
  final Map<ExpenseCategory, double> categoryTotals;

  DailyExpenseSummary({
    required this.date,
    required this.totalAmount,
    required this.categoryTotals,
  });
}

class MonthlyExpenseReport {
  final int year;
  final int month;
  final double totalAmount;
  final Map<ExpenseCategory, double> categoryTotals;
  final List<DailyExpenseSummary> dailySummaries;

  MonthlyExpenseReport({
    required this.year,
    required this.month,
    required this.totalAmount,
    required this.categoryTotals,
    required this.dailySummaries,
  });
}
