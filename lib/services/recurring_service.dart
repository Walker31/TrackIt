import 'package:flutter/foundation.dart';
import '../models/expenses.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'id_generator.dart';
import 'notification_service.dart';
import 'sync_outbox.dart';
import 'sync_service.dart';

enum Frequency {
  weekly('Weekly', 'week'),
  monthly('Monthly', 'month'),
  yearly('Yearly', 'year');

  final String label;
  final String unit;
  const Frequency(this.label, this.unit);

  static Frequency fromString(String v) =>
      values.firstWhere((f) => f.name == v, orElse: () => Frequency.monthly);
}

/// A transaction that repeats: rent, salary, subscriptions.
class RecurringRule {
  final String id;
  final double amount;
  final TxnType type;
  final ExpenseCategory category;
  final String? categoryId;
  final String? subcategoryId;
  final PaymentMethod? paymentMethod;
  final String? description;
  final Frequency frequency;

  /// Day of the month (monthly, yearly) or weekday 1–7 (weekly) it falls on,
  /// so a rule started on the 31st stays at month end instead of drifting.
  final int anchorDay;

  /// The next date (no time) a transaction is due.
  final DateTime nextDate;
  final DateTime? endDate;
  final bool active;

  const RecurringRule({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.categoryId,
    this.subcategoryId,
    this.paymentMethod,
    this.description,
    required this.frequency,
    required this.anchorDay,
    required this.nextDate,
    this.endDate,
    this.active = true,
  });

  bool get isIncome => type == TxnType.income;

  /// A rule that repeats [e] every [frequency], first due one period after
  /// [e]'s date.
  factory RecurringRule.from(Expense e, Frequency frequency) {
    final start = DateTime(
      e.timestamp.year,
      e.timestamp.month,
      e.timestamp.day,
    );
    final anchor = frequency == Frequency.weekly ? start.weekday : start.day;
    return RecurringRule(
      id: IdGenerator.uuid(),
      amount: e.amount,
      type: e.type,
      category: e.category,
      categoryId: e.categoryId,
      subcategoryId: e.subcategoryId,
      paymentMethod: e.paymentMethod,
      description: e.description,
      frequency: frequency,
      anchorDay: anchor,
      nextDate: advance(start, frequency, anchor),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'amount': amount,
    'type': type.name,
    'category': category.name,
    'category_id': categoryId,
    'subcategory_id': subcategoryId,
    'payment_method': paymentMethod?.name,
    'description': description,
    'frequency': frequency.name,
    'anchor_day': anchorDay,
    'next_date': _date(nextDate),
    'end_date': endDate == null ? null : _date(endDate!),
    'active': active ? 1 : 0,
  };

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
    id: m['id'] as String,
    amount: (m['amount'] as num).toDouble(),
    type: TxnType.fromString(m['type'] as String?),
    category: ExpenseCategory.fromString(m['category'] as String),
    categoryId: m['category_id'] as String?,
    subcategoryId: m['subcategory_id'] as String?,
    paymentMethod: PaymentMethod.fromString(m['payment_method'] as String?),
    description: m['description'] as String?,
    frequency: Frequency.fromString(m['frequency'] as String),
    anchorDay: m['anchor_day'] as int,
    nextDate: DateTime.parse(m['next_date'] as String),
    endDate: m['end_date'] == null
        ? null
        : DateTime.parse(m['end_date'] as String),
    active: m['active'] == 1,
  );

  RecurringRule copyWith({
    double? amount,
    DateTime? nextDate,
    bool? active,
    String? Function()? description,
  }) => RecurringRule(
    id: id,
    amount: amount ?? this.amount,
    type: type,
    category: category,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    paymentMethod: paymentMethod,
    description: description != null ? description() : this.description,
    frequency: frequency,
    anchorDay: anchorDay,
    nextDate: nextDate ?? this.nextDate,
    endDate: endDate,
    active: active ?? this.active,
  );

  /// The transaction this rule adds on [day].
  Expense expenseOn(DateTime day) => Expense(
    amount: amount,
    type: type,
    category: category,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    paymentMethod: paymentMethod,
    description: description,
    // Mid-morning, so it sorts after anything bought at midnight.
    timestamp: DateTime(day.year, day.month, day.day, 9),
  );

  /// The id of the transaction this rule adds on [day]: the same on every
  /// device, so two devices adding the same period make one server row.
  String entryUuid(DateTime day) => IdGenerator.derived(id, _date(day));

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The due date after [from] for a rule anchored on [anchor].
DateTime advance(DateTime from, Frequency f, int anchor) {
  switch (f) {
    case Frequency.weekly:
      return DateTime(from.year, from.month, from.day + 7);
    case Frequency.monthly:
      return _onDay(from.year, from.month + 1, anchor);
    case Frequency.yearly:
      return _onDay(from.year + 1, from.month, anchor);
  }
}

/// [day] of the month, or the month's last day when it's shorter.
DateTime _onDay(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// Stores recurring rules and adds their transactions when they fall due.
///
/// Rules sync with the server. So that two devices don't both add the same
/// rent payment, in server mode [addDue] runs only from [SyncService], right
/// after it pulled the rules (and so their latest `next_date`); and every
/// added transaction gets [RecurringRule.entryUuid] as its client id, so
/// even two devices adding the same period at once leave one copy.
class RecurringService {
  final DatabaseService _db = DatabaseService();

  /// Notification ids for "due tomorrow" reminders start here.
  static const _reminderBase = 6000;

  static const _table = 'recurring_rules';

  Future<List<RecurringRule>> all() async {
    final db = await _db.getDatabase();
    final rows = await db.query(_table, orderBy: 'active DESC, next_date ASC');
    return rows.map(RecurringRule.fromMap).toList();
  }

  /// Insert or update [rule], keeping its server id, and push it.
  Future<void> save(RecurringRule rule) async {
    final db = await _db.getDatabase();
    final row = {...rule.toMap(), 'is_synced': 0};
    await db.transaction((txn) async {
      final updated = await txn.update(
        _table,
        row,
        where: 'id = ?',
        whereArgs: [rule.id],
      );
      // A rule brought back with undo is inserted again under its old id;
      // the server revives it by client id.
      if (updated == 0) await txn.insert(_table, row);
    });
    await scheduleReminders();
    SyncService().performSync();
  }

  Future<void> delete(String id) async {
    final db = await _db.getDatabase();
    await db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        columns: ['remote_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      final remoteId = rows.isEmpty ? null : rows.first['remote_id'];
      if (remoteId != null) {
        await SyncOutbox.enqueueDelete(
          txn,
          '${ApiService.recurringRulesPath}$remoteId/',
        );
      }
      await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
    });
    await scheduleReminders();
    SyncService().performSync();
  }

  /// Adds every transaction that has fallen due up to [now] (catching up
  /// on missed periods) and moves each rule to its next date. Returns how
  /// many were added. A period whose transaction is already here (pulled
  /// from another device that added it first) is skipped.
  Future<int> addDue({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final db = await _db.getDatabase();
    var added = 0;
    for (final rule in await all()) {
      if (!rule.active) continue;
      var next = rule.nextDate;
      final due = <DateTime>[];
      // A year of weekly catch-up at most, if the app sat unopened.
      while (!next.isAfter(today) && due.length < 60) {
        if (rule.endDate != null && next.isAfter(rule.endDate!)) break;
        due.add(next);
        next = advance(next, rule.frequency, rule.anchorDay);
      }
      if (due.isEmpty) continue;
      final ended = rule.endDate != null && next.isAfter(rule.endDate!);
      // One transaction: the rule moves on exactly when its entries land.
      added += await db.transaction((txn) async {
        await txn.update(
          _table,
          {
            'next_date': RecurringRule._date(next),
            if (ended) 'active': 0,
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [rule.id],
        );
        var n = 0;
        for (final day in due) {
          final uuid = rule.entryUuid(day);
          final have = await txn.query(
            'expenses',
            columns: ['id'],
            where: 'uuid = ?',
            whereArgs: [uuid],
          );
          if (have.isNotEmpty) continue;
          await txn.insert('expenses', {
            ...rule.expenseOn(day).toMap(),
            'is_synced': 0,
            'uuid': uuid,
          });
          n++;
        }
        return n;
      });
    }
    if (added > 0) {
      await scheduleReminders();
      SyncService().performSync();
    }
    return added;
  }

  /// A notification the evening before each active rule is due.
  Future<void> scheduleReminders() async {
    try {
      final rules = await all();
      final notifications = NotificationService();
      for (var i = 0; i < 50; i++) {
        await notifications.cancel(_reminderBase + i);
      }
      var i = 0;
      for (final r in rules.where((r) => r.active).take(50)) {
        final at = DateTime(
          r.nextDate.year,
          r.nextDate.month,
          r.nextDate.day - 1,
          19,
        );
        if (at.isBefore(DateTime.now())) {
          i++;
          continue;
        }
        await notifications.scheduleOnce(
          id: _reminderBase + i++,
          title:
              '${r.description ?? (r.isIncome ? 'Income' : 'Payment')} due tomorrow',
          body:
              '₹${r.amount.toStringAsFixed(r.amount == r.amount.roundToDouble() ? 0 : 2)} '
              'will be added to your ${r.isIncome ? 'income' : 'spending'}.',
          at: at,
        );
      }
    } catch (e) {
      debugPrint('RecurringService: reminders failed ($e)');
    }
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
