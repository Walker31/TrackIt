class Settlement {
  final int? id;
  final int? remoteId;
  final int groupId;
  final int fromMemberId;
  final int toMemberId;
  final double amount;
  final DateTime timestamp;

  Settlement({
    this.id,
    this.remoteId,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'group_id': groupId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      groupId: map['group_id'] as int,
      fromMemberId: map['from_member_id'] as int,
      toMemberId: map['to_member_id'] as int,
      amount: double.parse(map['amount'].toString()),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
