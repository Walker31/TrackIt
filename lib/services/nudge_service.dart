import 'dart:math';

import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'notification_service.dart';
import 'nudge_lines.dart';
import 'prefs_service.dart';

/// One planned nudge.
typedef PlannedNudge = ({DateTime at, NudgeLine line});

/// The slot a time of day falls in.
NudgeSlot slotFor(DateTime t) => t.hour < 12
    ? NudgeSlot.morning
    : t.hour < 15
    ? NudgeSlot.lunch
    : t.hour < 18
    ? NudgeSlot.afternoon
    : NudgeSlot.evening;

/// A nudge a day for [days] days from [now]: a random minute between
/// [startMinute] and [endMinute] (minutes after midnight), a line that fits
/// that time (weekend lines on Saturdays and Sundays), no line twice in the
/// plan. Each day's choice comes from [salt] and the date, so planning again
/// the same day gives the same time and line. Times already past, and today
/// when [skipToday], are left out.
List<PlannedNudge> planNudges({
  required DateTime now,
  required int salt,
  int days = 14,
  int startMinute = 10 * 60,
  int endMinute = 19 * 60 + 30,
  bool skipToday = false,
  List<NudgeLine> lines = nudgeLines,
}) {
  final out = <PlannedNudge>[];
  final used = <int>{};
  for (var i = 0; i < days; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    final seed = salt ^ (day.year * 10000 + day.month * 100 + day.day);
    final rng = Random(seed);
    final minute = startMinute + rng.nextInt(endMinute - startMinute + 1);
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      minute ~/ 60,
      minute % 60,
    );
    final weekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final slot = slotFor(at);
    bool fits(NudgeLine l) =>
        l.slot == slot ||
        l.slot == NudgeSlot.any ||
        (weekend && l.slot == NudgeSlot.weekend);
    var pool = [
      for (var j = 0; j < lines.length; j++)
        if (fits(lines[j]) && !used.contains(j)) j,
    ];
    if (pool.isEmpty) {
      pool = [
        for (var j = 0; j < lines.length; j++)
          if (fits(lines[j])) j,
      ];
    }
    final pick = pool[rng.nextInt(pool.length)];
    used.add(pick);
    if (!at.isAfter(now)) continue;
    if (i == 0 && skipToday) continue;
    out.add((at: at, line: lines[pick]));
  }
  return out;
}

/// A friendly reminder at a random time each day to log spending, skipped
/// once something is logged that day. Tapping it opens "add expense".
class NudgeService {
  static const enabledKey = 'nudges_enabled';
  static const _saltKey = 'nudge_salt';
  static const _base = 7100;
  static const _days = 14;

  final PrefsService _prefs = PrefsService();

  Future<bool> enabled() => _prefs.getBool(enabledKey, true);

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(enabledKey, on);
    await reschedule();
  }

  /// A per-install number, so devices don't all nudge at the same minute.
  Future<int> _salt() async {
    final saved = int.tryParse(await _prefs.get(_saltKey) ?? '');
    if (saved != null) return saved;
    final salt = Random().nextInt(1 << 30);
    await _prefs.set(_saltKey, '$salt');
    return salt;
  }

  /// Whether an expense was added for today already.
  Future<bool> spentToday(DateTime now) async {
    final db = await DatabaseService().getDatabase();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM expenses WHERE timestamp >= ? AND timestamp < ?',
      [start, end],
    );
    return ((rows.first['n'] as int?) ?? 0) > 0;
  }

  Future<void> reschedule({DateTime? now}) async {
    final notifications = NotificationService();
    try {
      for (var i = 0; i < _days; i++) {
        await notifications.cancel(_base + i);
      }
      if (!await enabled()) return;
      final at = now ?? DateTime.now();
      final plan = planNudges(
        now: at,
        salt: await _salt(),
        days: _days,
        skipToday: await spentToday(at),
      );
      for (final n in plan) {
        final dayIndex = DateTime(
          n.at.year,
          n.at.month,
          n.at.day,
        ).difference(DateTime(at.year, at.month, at.day)).inDays;
        await notifications.scheduleOnce(
          id: _base + dayIndex,
          title: n.line.title,
          body: n.line.body,
          at: n.at,
          payload: 'add_expense',
          channelId: 'nudges_channel',
          channelName: 'Spending nudges',
        );
      }
    } catch (e) {
      debugPrint('NudgeService: $e');
    }
  }
}
