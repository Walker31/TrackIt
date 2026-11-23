import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'database_service.dart';
import 'id_generator.dart';

enum AccountKind {
  bank('Bank', Icons.account_balance_rounded),
  cash('Cash', Icons.payments_rounded),
  card('Credit card', Icons.credit_card_rounded),
  wallet('Wallet', Icons.account_balance_wallet_rounded);

  final String label;
  final IconData icon;
  const AccountKind(this.label, this.icon);

  static AccountKind fromString(String? v) =>
      values.firstWhere((k) => k.name == v, orElse: () => AccountKind.bank);
}

/// Where money sits: a bank account, cash, a credit card or a wallet.
class Account {
  final String id;
  final String name;
  final AccountKind kind;

  /// Balance before the first transaction recorded here. For a credit card,
  /// what was owed is a negative number.
  final double openingBalance;
  final bool archived;

  const Account({
    required this.id,
    required this.name,
    required this.kind,
    this.openingBalance = 0,
    this.archived = false,
  });

  factory Account.create(String name, AccountKind kind, double opening) =>
      Account(
        id: IdGenerator.uuid(),
        name: name,
        kind: kind,
        openingBalance: opening,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'opening_balance': openingBalance,
    'archived': archived ? 1 : 0,
  };

  factory Account.fromMap(Map<String, Object?> m) => Account(
    id: m['id'] as String,
    name: m['name'] as String,
    kind: AccountKind.fromString(m['kind'] as String?),
    openingBalance: (m['opening_balance'] as num).toDouble(),
    archived: m['archived'] == 1,
  );

  Account copyWith({
    String? name,
    AccountKind? kind,
    double? openingBalance,
    bool? archived,
  }) => Account(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    openingBalance: openingBalance ?? this.openingBalance,
    archived: archived ?? this.archived,
  );
}

typedef AccountBalance = ({Account account, double balance});

/// A savings goal: an amount to put aside, maybe by a date.
class Goal {
  final String id;
  final String name;
  final double target;
  final DateTime? targetDate;
  final bool archived;

  /// Sum of contributions (withdrawals are negative).
  final double saved;

  const Goal({
    required this.id,
    required this.name,
    required this.target,
    this.targetDate,
    this.archived = false,
    this.saved = 0,
  });

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  double get remaining => (target - saved).clamp(0, double.infinity);
  bool get reached => saved >= target;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'target': target,
    'target_date': targetDate == null ? null : _day(targetDate!),
    'archived': archived ? 1 : 0,
  };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
    id: m['id'] as String,
    name: m['name'] as String,
    target: (m['target'] as num).toDouble(),
    targetDate: m['target_date'] == null
        ? null
        : DateTime.parse(m['target_date'] as String),
    archived: m['archived'] == 1,
    saved: (m['saved'] as num?)?.toDouble() ?? 0,
  );
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What to put aside each month to reach [goal] by its date, counting this
/// month. Null without a date, once reached, or when the date has passed.
double? monthlyNeeded(Goal goal, {DateTime? now}) {
  final date = goal.targetDate;
  if (date == null || goal.reached) return null;
  final today = now ?? DateTime.now();
  final months = (date.year - today.year) * 12 + date.month - today.month + 1;
  if (months <= 0) return null;
  return goal.remaining / months;
}

/// Accounts, their balances, and transfers between them.
class AccountService {
  final DatabaseService _db = DatabaseService();

  Future<List<Account>> accounts({bool includeArchived = false}) async {
    final db = await _db.getDatabase();
    final rows = await db.query(
      'accounts',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'created_at ASC, name ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<void> save(Account account) async {
    final db = await _db.getDatabase();
    await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Balances: opening + income − spending, ± transfers. Archived accounts
  /// are left out.
  Future<List<AccountBalance>> balances() async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery('''
      SELECT a.*,
        a.opening_balance
        + COALESCE((SELECT SUM(CASE WHEN e.type = 'income' THEN e.amount
                                    ELSE -e.amount END)
                    FROM expenses e WHERE e.account_id = a.id), 0)
        + COALESCE((SELECT SUM(t.amount) FROM transfers t
                    WHERE t.to_account = a.id), 0)
        - COALESCE((SELECT SUM(t.amount) FROM transfers t
                    WHERE t.from_account = a.id), 0)
        AS balance
      FROM accounts a
      WHERE a.archived = 0
      ORDER BY a.created_at ASC, a.name ASC
    ''');
    return [
      for (final r in rows)
        (
          account: Account.fromMap(r),
          balance: (r['balance'] as num).toDouble(),
        ),
    ];
  }

  Future<void> transfer({
    required String from,
    required String to,
    required double amount,
    DateTime? on,
    String? note,
  }) async {
    if (from == to) throw ArgumentError('Pick two different accounts.');
    final db = await _db.getDatabase();
    await db.insert('transfers', {
      'id': IdGenerator.uuid(),
      'from_account': from,
      'to_account': to,
      'amount': amount,
      'date': _day(on ?? DateTime.now()),
      'note': note,
    });
  }

  /// Transfers touching [accountId], newest first.
  Future<List<Map<String, Object?>>> transfersFor(String accountId) async {
    final db = await _db.getDatabase();
    return db.query(
      'transfers',
      where: 'from_account = ? OR to_account = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC, created_at DESC',
    );
  }

  Future<void> deleteTransfer(String id) async {
    final db = await _db.getDatabase();
    await db.delete('transfers', where: 'id = ?', whereArgs: [id]);
  }

  /// The account most recently used for a transaction, to pre-select.
  Future<String?> lastUsed() async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery('''
      SELECT e.account_id FROM expenses e
      JOIN accounts a ON a.id = e.account_id AND a.archived = 0
      ORDER BY e.id DESC LIMIT 1
    ''');
    return rows.isEmpty ? null : rows.first['account_id'] as String?;
  }
}

/// Savings goals and money put towards them.
class GoalService {
  final DatabaseService _db = DatabaseService();

  Future<List<Goal>> goals({bool includeArchived = false}) async {
    final db = await _db.getDatabase();
    final rows = await db.rawQuery('''
      SELECT g.*, COALESCE((SELECT SUM(c.amount) FROM goal_contributions c
                            WHERE c.goal_id = g.id), 0) AS saved
      FROM goals g
      ${includeArchived ? '' : 'WHERE g.archived = 0'}
      ORDER BY g.archived ASC, g.created_at ASC
    ''');
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal> create(String name, double target, {DateTime? by}) async {
    final goal = Goal(
      id: IdGenerator.uuid(),
      name: name,
      target: target,
      targetDate: by,
    );
    await save(goal);
    return goal;
  }

  Future<void> save(Goal goal) async {
    final db = await _db.getDatabase();
    await db.insert(
      'goals',
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.getDatabase();
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  /// Puts [amount] towards the goal (negative to take money out).
  Future<void> contribute(
    String goalId,
    double amount, {
    DateTime? on,
    String? note,
  }) async {
    final db = await _db.getDatabase();
    await db.insert('goal_contributions', {
      'id': IdGenerator.uuid(),
      'goal_id': goalId,
      'amount': amount,
      'date': _day(on ?? DateTime.now()),
      'note': note,
    });
  }

  Future<List<Map<String, Object?>>> contributions(String goalId) async {
    final db = await _db.getDatabase();
    return db.query(
      'goal_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
  }

  Future<void> deleteContribution(String id) async {
    final db = await _db.getDatabase();
    await db.delete('goal_contributions', where: 'id = ?', whereArgs: [id]);
  }
}
