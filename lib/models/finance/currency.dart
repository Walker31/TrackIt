import 'package:intl/intl.dart';

/// A currency a transaction can be entered in. Totals stay in rupees: a
/// foreign amount is converted at the rate given when it's saved.
class Currency {
  final String code;
  final String symbol;
  final String name;
  const Currency(this.code, this.symbol, this.name);

  bool get isHome => code == homeCurrency.code;

  /// "$12.50", "€8", "¥1,200".
  String format(double amount) {
    final whole = amount == amount.roundToDouble();
    return '$symbol${NumberFormat(whole ? '#,##0' : '#,##0.00').format(amount)}';
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const homeCurrency = Currency('INR', '₹', 'Indian rupee');

/// The usual travel currencies, home first.
const currencies = <Currency>[
  homeCurrency,
  Currency('USD', r'$', 'US dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British pound'),
  Currency('AED', 'AED ', 'UAE dirham'),
  Currency('SGD', r'S$', 'Singapore dollar'),
  Currency('THB', '฿', 'Thai baht'),
  Currency('JPY', '¥', 'Japanese yen'),
  Currency('AUD', r'A$', 'Australian dollar'),
  Currency('CAD', r'C$', 'Canadian dollar'),
  Currency('MYR', 'RM ', 'Malaysian ringgit'),
  Currency('IDR', 'Rp ', 'Indonesian rupiah'),
  Currency('LKR', 'Rs ', 'Sri Lankan rupee'),
  Currency('NPR', 'Rs ', 'Nepalese rupee'),
  Currency('CHF', 'CHF ', 'Swiss franc'),
];

Currency currencyFor(String? code) => code == null
    ? homeCurrency
    : currencies.firstWhere(
        (c) => c.code == code,
        orElse: () => Currency(code, '$code ', code),
      );

/// Rupees for [amount] of a foreign currency at [rate] rupees per unit,
/// rounded to paise.
double toHome(double amount, double rate) =>
    (amount * rate * 100).roundToDouble() / 100;
