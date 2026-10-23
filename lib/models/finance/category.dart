import 'package:flutter/material.dart';
import 'expense_category.dart';

/// Mirrors `transactions.type` / `categories.type` in the PaisaPulse blueprint.
enum TxnType {
  expense,
  income;

  static TxnType fromString(String? v) =>
      v == 'income' ? TxnType.income : TxnType.expense;
}

/// Mirrors the `transactions.payment_method` CHECK constraint.
enum PaymentMethod {
  cash('Cash', Icons.payments_outlined),
  card('Card', Icons.credit_card),
  upi('UPI', Icons.qr_code_2),
  netbanking('Net banking', Icons.account_balance),
  wallet('Wallet', Icons.account_balance_wallet_outlined),
  other('Other', Icons.more_horiz);

  final String label;
  final IconData icon;
  const PaymentMethod(this.label, this.icon);

  static PaymentMethod? fromString(String? v) {
    if (v == null) return null;
    for (final p in values) {
      if (p.name == v) return p;
    }
    return null;
  }
}

/// `categories` row. `isDefault` (userId == null) means system-provided.
class Category {
  final String id;
  final String? userId;
  final String name;
  final String? icon;
  final String? color; // #RRGGBB
  final TxnType type;
  final bool isDefault;

  const Category({
    required this.id,
    this.userId,
    required this.name,
    this.icon,
    this.color,
    this.type = TxnType.expense,
    this.isDefault = false,
  });

  Color get colorValue {
    final hex = (color ?? '#5F5E5A').replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData get iconData => categoryIcons[icon] ?? Icons.category_outlined;

  /// Bridge to the legacy enum still used by charts and group expenses.
  ExpenseCategory get legacy => switch (name) {
    'Food & Dining' => ExpenseCategory.food,
    'Transport' => ExpenseCategory.transport,
    'Shopping' => ExpenseCategory.shopping,
    'Health & Fitness' => ExpenseCategory.health,
    'Entertainment' => ExpenseCategory.entertainment,
    _ => ExpenseCategory.other,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'icon': icon,
    'color': color,
    'type': type.name,
    'is_default': isDefault ? 1 : 0,
  };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'].toString(),
    userId: m['user_id']?.toString(),
    name: m['name'] as String,
    icon: m['icon'] as String?,
    color: m['color'] as String?,
    type: TxnType.fromString(m['type'] as String?),
    isDefault: (m['is_default'] ?? 0) == 1 || m['is_default'] == true,
  );
}

class Subcategory {
  final String id;
  final String categoryId;
  final String name;

  const Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'name': name,
  };

  factory Subcategory.fromMap(Map<String, dynamic> m) => Subcategory(
    id: m['id'].toString(),
    categoryId: m['category_id'].toString(),
    name: m['name'] as String,
  );
}

/// Blueprint icon names -> Material icons.
const Map<String, IconData> categoryIcons = {
  'utensils': Icons.restaurant,
  'car': Icons.directions_car,
  'home': Icons.home_outlined,
  'shopping-bag': Icons.shopping_bag_outlined,
  'heart': Icons.favorite_border,
  'movie': Icons.movie_outlined,
  'plane': Icons.flight,
  'book': Icons.menu_book_outlined,
  'piggy-bank': Icons.savings_outlined,
  'dots': Icons.more_horiz,
  'briefcase': Icons.work_outline,
  'building-store': Icons.storefront_outlined,
  'trending-up': Icons.trending_up,
  'gift': Icons.card_giftcard,
};

String _cid(int n) =>
    '00000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';

/// Default categories, identical to the blueprint seed.
final List<Category> defaultCategories = [
  for (final r in const [
    (1, 'Food & Dining', 'utensils', '#D85A30', 'expense'),
    (2, 'Transport', 'car', '#378ADD', 'expense'),
    (3, 'Housing & Utilities', 'home', '#1D9E75', 'expense'),
    (4, 'Shopping', 'shopping-bag', '#D4537E', 'expense'),
    (5, 'Health & Fitness', 'heart', '#E24B4A', 'expense'),
    (6, 'Entertainment', 'movie', '#7F77DD', 'expense'),
    (7, 'Travel', 'plane', '#0C447C', 'expense'),
    (8, 'Education', 'book', '#BA7517', 'expense'),
    (9, 'Savings & Investments', 'piggy-bank', '#3B6D11', 'expense'),
    (10, 'Miscellaneous', 'dots', '#5F5E5A', 'expense'),
    (11, 'Salary', 'briefcase', '#0F6E56', 'income'),
    (12, 'Business & Freelance', 'building-store', '#3C3489', 'income'),
    (13, 'Investment Returns', 'trending-up', '#085041', 'income'),
    (14, 'Gifts Received', 'gift', '#993556', 'income'),
    (15, 'Other Income', 'dots', '#444441', 'income'),
  ])
    Category(
      id: _cid(r.$1),
      name: r.$2,
      icon: r.$3,
      color: r.$4,
      type: TxnType.fromString(r.$5),
      isDefault: true,
    ),
];

/// Default subcategories keyed by default-category number.
const Map<int, List<String>> _defaultSubs = {
  1: ['Groceries', 'Restaurants', 'Cafes & Coffee', 'Food Delivery'],
  2: [
    'Fuel',
    'Public Transport',
    'Cab & Ride-share',
    'Parking & Tolls',
    'Vehicle Maintenance',
  ],
  3: [
    'Rent / EMI',
    'Electricity',
    'Water',
    'Internet & Cable',
    'Mobile Recharge',
    'Maintenance & Repairs',
  ],
  4: [
    'Clothing & Accessories',
    'Electronics',
    'Home & Furniture',
    'Personal Care',
  ],
  5: ['Doctor & Medicines', 'Gym & Fitness', 'Health Insurance'],
  6: ['Movies & Shows', 'Subscriptions', 'Games & Hobbies', 'Events & Outings'],
  7: [
    'Flights',
    'Hotels & Stays',
    'Local Transport',
    'Sightseeing & Activities',
  ],
  8: ['Courses & Certifications', 'Books & Supplies', 'Tuition & Fees'],
  9: ['SIP / Mutual Funds', 'Fixed Deposit', 'Insurance Premium', 'Stocks'],
  10: ['Gifts & Donations', 'Fees & Charges', 'Other'],
  11: ['Bonus & Incentives', 'Reimbursements'],
};

final List<Subcategory> defaultSubcategories = [
  for (final e in _defaultSubs.entries)
    for (final name in e.value)
      Subcategory(
        id: '${_cid(e.key)}:$name',
        categoryId: _cid(e.key),
        name: name,
      ),
];
