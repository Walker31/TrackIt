import 'expense_category.dart';

enum SplitType {
  equal('equal'),
  exact('exact'),
  percentage('percentage');

  final String value;
  const SplitType(this.value);

  static SplitType fromString(String value) {
    return SplitType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SplitType.equal,
    );
  }
}

class ExpenseSplit {
  final int? id;
  final int? remoteId;
  final int expenseId;
  final int memberId;
  final double shareAmount;

  ExpenseSplit({
    this.id,
    this.remoteId,
    required this.expenseId,
    required this.memberId,
    required this.shareAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'expense_id': expenseId,
      'member_id': memberId,
      'share_amount': shareAmount,
    };
  }

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      expenseId: map['expense_id'] as int,
      memberId: map['member_id'] as int,
      shareAmount: double.parse(map['share_amount'].toString()),
    );
  }
}

class GroupExpense {
  final int? id;
  final int? remoteId;
  final int groupId;
  final int payerMemberId;
  final double amount;
  final ExpenseCategory category;
  final String? description;
  final DateTime timestamp;
  final String? receiptUrl;
  final SplitType splitType;
  final List<ExpenseSplit> splits;

  GroupExpense({
    this.id,
    this.remoteId,
    required this.groupId,
    required this.payerMemberId,
    required this.amount,
    required this.category,
    this.description,
    required this.timestamp,
    this.receiptUrl,
    this.splitType = SplitType.equal,
    this.splits = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'group_id': groupId,
      'payer_member_id': payerMemberId,
      'amount': amount,
      'category': category.name,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'receipt_url': receiptUrl,
      'split_type': splitType.value,
    };
  }

  factory GroupExpense.fromMap(
    Map<String, dynamic> map, {
    List<ExpenseSplit> splits = const [],
  }) {
    return GroupExpense(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      groupId: map['group_id'] as int,
      payerMemberId: map['payer_member_id'] as int,
      amount: double.parse(map['amount'].toString()),
      category: ExpenseCategory.fromString(map['category'] as String),
      description: map['description'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      receiptUrl: map['receipt_url'] as String?,
      splitType: SplitType.fromString(map['split_type'] as String? ?? 'equal'),
      splits: splits,
    );
  }

  GroupExpense copyWith({int? id, int? remoteId, List<ExpenseSplit>? splits}) {
    return GroupExpense(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      groupId: groupId,
      payerMemberId: payerMemberId,
      amount: amount,
      category: category,
      description: description,
      timestamp: timestamp,
      receiptUrl: receiptUrl,
      splitType: splitType,
      splits: splits ?? this.splits,
    );
  }
}

class MemberBalance {
  final int memberId;
  final String username;
  final double balance;

  MemberBalance({
    required this.memberId,
    required this.username,
    required this.balance,
  });
}
