/// `events` row: a trip/occasion that transactions can be tagged with,
/// independent of the transaction date. (Distinct from split-expense
/// `Group`s, which the app shows under "Events" on the wallet screen.)
class SpendEvent {
  final String id;
  final String title;
  final DateTime eventDate;
  final DateTime? endDate;
  final String? description;

  const SpendEvent({
    required this.id,
    required this.title,
    required this.eventDate,
    this.endDate,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'event_date': dateOnly(eventDate),
    'end_date': endDate == null ? null : dateOnly(endDate!),
    'description': description,
  };

  factory SpendEvent.fromMap(Map<String, dynamic> m) => SpendEvent(
    id: m['id'].toString(),
    title: m['title'] as String,
    eventDate: DateTime.parse(m['event_date'] as String),
    endDate: m['end_date'] == null
        ? null
        : DateTime.parse(m['end_date'] as String),
    description: m['description'] as String?,
  );
}

/// `budgets` row: per-category monthly limit.
class Budget {
  final String id;
  final String categoryId;
  final DateTime month; // first day of month
  final double limitAmount;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limitAmount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'month': dateOnly(DateTime(month.year, month.month, 1)),
    'limit_amount': limitAmount,
  };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
    id: m['id'].toString(),
    categoryId: m['category_id'].toString(),
    month: DateTime.parse(m['month'] as String),
    limitAmount: (m['limit_amount'] as num).toDouble(),
  );
}

/// `YYYY-MM-DD`, the format the blueprint's DATE columns use.
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
