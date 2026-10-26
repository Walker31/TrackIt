import 'package:intl/intl.dart';

/// Formats a rupee amount with Indian digit grouping, keeping paise only
/// when present: 1250 -> ₹1,250, 50000 -> ₹50,000, 99.5 -> ₹99.50.
String formatRupees(double amount) {
  final whole = amount == amount.roundToDouble();
  return '₹${NumberFormat(whole ? '#,##,##0' : '#,##,##0.00', 'en_IN').format(amount)}';
}

/// Short form for chart axes: ₹950, ₹1.2k, ₹3.4L.
String formatRupeesCompact(double amount) {
  if (amount >= 100000) return '₹${_trim(amount / 100000)}L';
  if (amount >= 1000) return '₹${_trim(amount / 1000)}k';
  return '₹${amount.toStringAsFixed(0)}';
}

String _trim(double v) =>
    v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.0', '');
