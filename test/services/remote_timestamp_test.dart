import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/services/sync_service.dart';

/// The server stores only a calendar day (`txn_date`). Pulled rows used to
/// keep that bare date, which sorts before "YYYY-MM-DDT00:00:00" and so
/// fell out of every day/month range query (Today showed ₹0).
void main() {
  final ts = SyncService.timestampFromRemote;
  const day = '2026-10-25';
  final startOfDay = DateTime(2026, 10, 25).toIso8601String();
  final endOfDay = DateTime(2026, 10, 25, 23, 59, 59).toIso8601String();

  bool inDayRange(String value) =>
      value.compareTo(startOfDay) >= 0 && value.compareTo(endOfDay) <= 0;

  test('never stores a bare date', () {
    final result = ts({'txn_date': day}, null);
    expect(result.length, greaterThan(10));
    expect(inDayRange(result), isTrue);
  });

  test('keeps the local time when the day is unchanged', () {
    const local = '2026-10-25T18:36:12.000';
    expect(ts({'txn_date': day}, local), local);
  });

  test("ignores the local time when the server's day differs", () {
    final result = ts({'txn_date': day}, '2026-10-24T18:36:12.000');
    expect(DateTime.parse(result), DateTime(2026, 10, 25));
  });

  test("uses the server's created_at time on that day", () {
    final created = DateTime(2026, 10, 25, 14, 30, 5).toUtc();
    final result = ts({
      'txn_date': day,
      'created_at': created.toIso8601String(),
    }, null);
    expect(DateTime.parse(result), DateTime(2026, 10, 25, 14, 30, 5));
  });

  test('falls back to local midnight when created_at is another day', () {
    final created = DateTime(2026, 10, 27, 9).toUtc();
    final result = ts({
      'txn_date': day,
      'created_at': created.toIso8601String(),
    }, null);
    expect(DateTime.parse(result), DateTime(2026, 10, 25));
    expect(inDayRange(result), isTrue);
  });

  test('passes a full legacy timestamp through', () {
    const full = '2026-10-25T10:15:00.000';
    expect(DateTime.parse(ts({'timestamp': full}, null)), DateTime.parse(full));
  });

  test('keeps the local value when the server sends no date', () {
    const local = '2026-10-25T08:00:00.000';
    expect(ts(<String, dynamic>{}, local), local);
  });
}
