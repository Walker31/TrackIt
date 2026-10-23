import 'category.dart';
import 'expense_category.dart';
import 'spend_event.dart' show dateOnly;

/// A transaction (the blueprint's `transactions` table). Kept under the
/// `Expense` name because most of the app already depends on it; `type`
/// distinguishes expenses from income.
class Expense {
  final int? id;
  final double amount;

  /// Legacy bucket used by charts/group expenses; derived from the
  /// blueprint category when [categoryId] is set.
  final ExpenseCategory category;
  final DateTime timestamp; // `txn_date`
  final String? description; // `note`

  final TxnType type;
  final String? categoryId;
  final String? subcategoryId;
  final String? eventId;
  final PaymentMethod? paymentMethod;
  final String? attachmentUrl;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.timestamp,
    this.description,
    this.type = TxnType.expense,
    this.categoryId,
    this.subcategoryId,
    this.eventId,
    this.paymentMethod,
    this.attachmentUrl,
  });

  bool get isIncome => type == TxnType.income;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'type': type.name,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'event_id': eventId,
      'payment_method': paymentMethod?.name,
      'attachment_url': attachmentUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: double.parse(map['amount'].toString()),
      category: ExpenseCategory.fromString(map['category'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String?,
      type: TxnType.fromString(map['type'] as String?),
      categoryId: map['category_id'] as String?,
      subcategoryId: map['subcategory_id'] as String?,
      eventId: map['event_id'] as String?,
      paymentMethod: PaymentMethod.fromString(map['payment_method'] as String?),
      attachmentUrl: map['attachment_url'] as String?,
    );
  }

  /// Request body for `POST /api/transactions/` (blueprint field names).
  Map<String, dynamic> toApi() => {
    'amount': amount.toStringAsFixed(2),
    'type': type.name,
    'txn_date': dateOnly(timestamp),
    'category': categoryId,
    'subcategory': subcategoryId,
    'event': eventId,
    'payment_method': paymentMethod?.name,
    'note': description,
    'attachment_url': attachmentUrl,
  };

  Expense copyWith({
    int? id,
    double? amount,
    ExpenseCategory? category,
    DateTime? timestamp,
    String? description,
    TxnType? type,
    String? categoryId,
    String? subcategoryId,
    String? eventId,
    PaymentMethod? paymentMethod,
    String? attachmentUrl,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      eventId: eventId ?? this.eventId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
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
