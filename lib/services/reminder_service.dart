import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'nudge_service.dart';
import 'prefs_service.dart';
import 'progress_service.dart';

/// The daily check-in: at a time the user picks, skipped on days they've
/// already logged something, mentioning their workout streak.
///
/// Local notifications can't check a condition when they fire, so the next
/// two weeks are scheduled as single notifications and today's is left out
/// once something is logged. [reschedule] runs on start and after logging.
class ReminderService {
  static const _base = 7000;
  static const _days = 14;
  static const _legacyDailyId = 1;

  final PrefsService _prefs = PrefsService();

  Future<bool> enabled() => _prefs.getBool(PrefsService.reminderEnabled, true);

  /// (hour, minute); 8 PM by default.
  Future<(int, int)> time() async {
    final raw = await _prefs.get(PrefsService.reminderTime) ?? '20:00';
    final parts = raw.split(':');
    return (
      int.tryParse(parts.first) ?? 20,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(PrefsService.reminderEnabled, on);
    await reschedule();
  }

  Future<void> setTime(int hour, int minute) async {
    await _prefs.set(
      PrefsService.reminderTime,
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
    await reschedule();
  }

  /// Whether anything (an expense or a completed set) was logged on [day].
  Future<bool> loggedOn(DateTime day) async {
    final db = await DatabaseService().getDatabase();
    final key = DateTime(day.year, day.month, day.day).toIso8601String();
    final next = DateTime(day.year, day.month, day.day + 1).toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM expenses WHERE timestamp >= ? AND timestamp < ?)
        + (SELECT COUNT(*) FROM sets s
             JOIN exercises e ON e.id = s.exercise_id
             JOIN workouts w ON w.id = e.workout_id
           WHERE s.is_completed = 1 AND w.timestamp >= ? AND w.timestamp < ?)
        AS n
      ''',
      [key, next, key, next],
    );
    return ((rows.first['n'] as int?) ?? 0) > 0;
  }

  Future<void> reschedule({DateTime? now}) async {
    // The daytime nudges follow the same moments (start-up, a new entry).
    await NudgeService().reschedule(now: now);
    final notifications = NotificationService();
    try {
      await notifications.cancel(_legacyDailyId);
      for (var i = 0; i < _days; i++) {
        await notifications.cancel(_base + i);
      }
      if (!await enabled()) return;
      final (hour, minute) = await time();
      final at = now ?? DateTime.now();
      final skipToday = await loggedOn(at);
      final streak = await ProgressService().streak(now: at);
      for (var i = 0; i < _days; i++) {
        final when = DateTime(at.year, at.month, at.day + i, hour, minute);
        if (!when.isAfter(at)) continue;
        if (i == 0 && skipToday) continue;
        await notifications.scheduleOnce(
          id: _base + i,
          title: 'Time for a quick check-in',
          body: i == 0 && streak > 1
              ? 'Keep your $streak-day streak going: log today\'s spending '
                    'or workout.'
              : 'Log today\'s spending and workout. It takes a minute.',
          at: when,
        );
      }
    } catch (e) {
      debugPrint('ReminderService: $e');
    }
  }
}
