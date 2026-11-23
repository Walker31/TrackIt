import '../models/expenses.dart';

/// What the transaction search shows. Every field narrows the results;
/// empty fields match everything.
class TransactionFilter {
  final String query;
  final TxnType? type;
  final Set<String> categoryIds;
  final Set<PaymentMethod> paymentMethods;
  final DateTime? from; // inclusive, date only
  final DateTime? to; // inclusive, date only
  final double? minAmount;
  final double? maxAmount;

  /// Only transactions paid from or into this account.
  final String? accountId;

  const TransactionFilter({
    this.query = '',
    this.type,
    this.categoryIds = const {},
    this.paymentMethods = const {},
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
    this.accountId,
  });

  bool get isEmpty =>
      query.trim().isEmpty &&
      type == null &&
      categoryIds.isEmpty &&
      paymentMethods.isEmpty &&
      from == null &&
      to == null &&
      minAmount == null &&
      maxAmount == null &&
      accountId == null;

  /// Filters other than the text query, for the "N filters" badge.
  int get activeCount =>
      (type == null ? 0 : 1) +
      (categoryIds.isEmpty ? 0 : 1) +
      (paymentMethods.isEmpty ? 0 : 1) +
      (from == null && to == null ? 0 : 1) +
      (minAmount == null && maxAmount == null ? 0 : 1) +
      (accountId == null ? 0 : 1);

  TransactionFilter copyWith({
    String? query,
    TxnType? Function()? type,
    Set<String>? categoryIds,
    Set<PaymentMethod>? paymentMethods,
    DateTime? Function()? from,
    DateTime? Function()? to,
    double? Function()? minAmount,
    double? Function()? maxAmount,
    String? Function()? accountId,
  }) => TransactionFilter(
    query: query ?? this.query,
    type: type != null ? type() : this.type,
    categoryIds: categoryIds ?? this.categoryIds,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    minAmount: minAmount != null ? minAmount() : this.minAmount,
    maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
    accountId: accountId != null ? accountId() : this.accountId,
  );

  /// Whether [e] (whose category is [category]) passes. The text query
  /// matches the note, the category name or the amount, word by word.
  bool matches(Expense e, Category category) {
    if (type != null && e.type != type) return false;
    if (accountId != null && e.accountId != accountId) return false;
    if (categoryIds.isNotEmpty && !categoryIds.contains(category.id)) {
      return false;
    }
    if (paymentMethods.isNotEmpty &&
        (e.paymentMethod == null ||
            !paymentMethods.contains(e.paymentMethod))) {
      return false;
    }
    final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    if (from != null && day.isBefore(_day(from!))) return false;
    if (to != null && day.isAfter(_day(to!))) return false;
    if (minAmount != null && e.amount < minAmount!) return false;
    if (maxAmount != null && e.amount > maxAmount!) return false;

    final words = query.trim().toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return true;
    final haystack = [
      e.description ?? '',
      category.name,
      e.paymentMethod?.label ?? '',
      _amountText(e.amount),
    ].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _amountText(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2);
}

/// Totals for a list of transactions.
({double spent, double received, int count}) totalsOf(Iterable<Expense> list) {
  var spent = 0.0, received = 0.0, count = 0;
  for (final e in list) {
    count++;
    if (e.isIncome) {
      received += e.amount;
    } else {
      spent += e.amount;
    }
  }
  return (spent: spent, received: received, count: count);
}
