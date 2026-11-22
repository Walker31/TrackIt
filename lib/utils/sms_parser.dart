import '../models/expenses.dart';

/// What a bank or UPI SMS says about one transaction.
class ParsedSms {
  final double amount;
  final TxnType type;
  final String? merchant;
  final PaymentMethod? paymentMethod;
  final DateTime? date;

  /// A default category name ("Food & Dining") guessed from the merchant.
  final String? categoryName;

  const ParsedSms({
    required this.amount,
    required this.type,
    this.merchant,
    this.paymentMethod,
    this.date,
    this.categoryName,
  });

  @override
  String toString() =>
      'ParsedSms($amount ${type.name} ${merchant ?? '-'} '
      '${paymentMethod?.name ?? '-'} ${date ?? '-'} ${categoryName ?? '-'})';
}

final _amountRe = RegExp(
  r'(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
  caseSensitive: false,
);

const _debitWords = [
  'debited',
  'spent',
  'sent',
  'paid',
  'withdrawn',
  'purchase',
  'charged',
  'dr ',
];
const _creditWords = ['credited', 'received', 'deposited', 'refund', 'cr '];

/// Merchant words → default category name.
const _merchantCategories = <String, String>{
  'swiggy': 'Food & Dining',
  'zomato': 'Food & Dining',
  'blinkit': 'Food & Dining',
  'zepto': 'Food & Dining',
  'bigbasket': 'Food & Dining',
  'dunzo': 'Food & Dining',
  'starbucks': 'Food & Dining',
  'cafe': 'Food & Dining',
  'restaurant': 'Food & Dining',
  'uber': 'Transport',
  'ola': 'Transport',
  'rapido': 'Transport',
  'metro': 'Transport',
  'fuel': 'Transport',
  'petrol': 'Transport',
  'irctc': 'Travel',
  'makemytrip': 'Travel',
  'goibibo': 'Travel',
  'indigo': 'Travel',
  'airbnb': 'Travel',
  'amazon': 'Shopping',
  'flipkart': 'Shopping',
  'myntra': 'Shopping',
  'ajio': 'Shopping',
  'nykaa': 'Shopping',
  'netflix': 'Entertainment',
  'spotify': 'Entertainment',
  'hotstar': 'Entertainment',
  'bookmyshow': 'Entertainment',
  'pharmacy': 'Health & Fitness',
  'apollo': 'Health & Fitness',
  'gym': 'Health & Fitness',
  'cult': 'Health & Fitness',
  'airtel': 'Housing & Utilities',
  'jio': 'Housing & Utilities',
  'electricity': 'Housing & Utilities',
  'bescom': 'Housing & Utilities',
  'rent': 'Housing & Utilities',
  'salary': 'Salary',
};

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Reads one transaction out of a bank or UPI message. Null when the text
/// has no amount or doesn't say money went out or came in (OTPs, offers).
ParsedSms? parseBankSms(String text, {DateTime? now}) {
  final lower = ' ${text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')} ';
  // Offers and balance alerts aren't transactions.
  if (RegExp(r'\botp\b|one time password|cashback upto|win ').hasMatch(lower)) {
    return null;
  }

  final debitAt = _firstIndex(lower, _debitWords);
  final creditAt = _firstIndex(lower, _creditWords);
  if (debitAt < 0 && creditAt < 0) return null;
  // "debited ... and credited to a/c X" is still a debit: the first verb wins.
  final type = debitAt >= 0 && (creditAt < 0 || debitAt < creditAt)
      ? TxnType.expense
      : TxnType.income;

  // The transaction amount is the first one; "Avl bal Rs.X" comes later.
  final amountMatch = _amountRe.firstMatch(text);
  if (amountMatch == null) return null;
  final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  final merchant = _merchant(text);
  final method = lower.contains('upi') || lower.contains('vpa')
      ? PaymentMethod.upi
      : lower.contains(' atm ') || lower.contains('withdrawn')
      ? PaymentMethod.cash
      : lower.contains('card')
      ? PaymentMethod.card
      : RegExp(r'neft|imps|rtgs|net ?banking').hasMatch(lower)
      ? PaymentMethod.netbanking
      : null;

  String? category;
  final haystack = '${merchant ?? ''} $lower'.toLowerCase();
  for (final e in _merchantCategories.entries) {
    if (RegExp('\\b${e.key}').hasMatch(haystack)) {
      category = e.value;
      break;
    }
  }
  if (category == 'Salary' && type == TxnType.expense) category = null;

  return ParsedSms(
    amount: amount,
    type: type,
    merchant: merchant,
    paymentMethod: method,
    date: _date(text, now ?? DateTime.now()),
    categoryName: category,
  );
}

int _firstIndex(String s, List<String> words) {
  var best = -1;
  for (final w in words) {
    final i = s.indexOf(w);
    if (i >= 0 && (best < 0 || i < best)) best = i;
  }
  return best;
}

String? _merchant(String text) {
  final patterns = [
    RegExp(
      r'\bat\s+([A-Za-z0-9&.\x27 *-]{2,40}?)(?=\s+(?:on|via|ref|using|for)\b|[.,]|$)',
      caseSensitive: false,
    ),
    RegExp(r'to\s+vpa\s+([A-Za-z0-9._@-]+)', caseSensitive: false),
    RegExp(
      r'\bto\s+([A-Za-z][A-Za-z0-9&.\x27 -]{1,40}?)(?=\s+(?:on|via|ref|upi|from|a/c)\b|[.,(]|$)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bfrom\s+(?:vpa\s+)?([A-Za-z][A-Za-z0-9._@&\x27 -]{1,40}?)(?=\s+(?:on|via|ref|upi|to)\b|[.,(]|$)',
      caseSensitive: false,
    ),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    var name = m.group(1)!.trim();
    // Account numbers and bank names aren't merchants.
    if (RegExp(
      r'a/c|acct|account|x{2,}|\*\d|bank\b',
      caseSensitive: false,
    ).hasMatch(name)) {
      continue;
    }
    if (name.contains('@')) name = name.split('@').first;
    name = name.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (name.isEmpty) continue;
    return name
        .split(' ')
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }
  return null;
}

DateTime? _date(String text, DateTime now) {
  DateTime? valid(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    if (date.month != m) return null;
    // Messages are about the past; ignore anything far in the future.
    if (date.isAfter(now.add(const Duration(days: 1)))) return null;
    return date;
  }

  final iso = RegExp(r'\b(20\d\d)-(\d\d)-(\d\d)\b').firstMatch(text);
  if (iso != null) {
    return valid(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  final named = RegExp(
    r'\b(\d{1,2})[- ]?([A-Za-z]{3})[a-z]*[- ,]?(\d{2,4})\b',
  ).firstMatch(text);
  if (named != null) {
    final m = _months[named.group(2)!.toLowerCase()];
    if (m != null) {
      return valid(int.parse(named.group(3)!), m, int.parse(named.group(1)!));
    }
  }
  final dmy = RegExp(
    r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b',
  ).firstMatch(text);
  if (dmy != null) {
    return valid(
      int.parse(dmy.group(3)!),
      int.parse(dmy.group(2)!),
      int.parse(dmy.group(1)!),
    );
  }
  return null;
}
