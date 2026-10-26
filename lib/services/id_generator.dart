import 'dart:math';

/// The one place ids are made. The pattern, per kind of row:
///
/// - **Every table** has a local integer `id` (SQLite autoincrement) used only
///   for joins on this device; it never leaves it.
/// - **Synced rows** (expenses, workouts, exercises, sets, routines, groups,
///   group members, group expenses, settlements) also get a [uuid] at insert,
///   stored in `uuid` and sent as `client_id`, so a retried push can't
///   create a server duplicate. Rows pulled from the server keep the
///   `client_id` it returns (see [orNew]).
/// - **Catalog rows** whose primary key is shared with the server
///   (categories, events, budgets) use a [uuid] as their `id`.
/// - **Subcategories** use [subcategoryId], a deterministic key that matches
///   the server's built-in defaults.
/// - Rows only ever sent nested in a parent (routine exercises, expense
///   splits) need nothing beyond the local `id`.
///
/// A SQLite trigger still fills a missing `uuid` as a safety net, but every
/// insert path sets it explicitly through here.
class IdGenerator {
  IdGenerator._();

  static final _random = Random.secure();

  /// Random RFC 4122 v4 UUID, e.g. `3f2b8c1e-9a4d-4e7f-b1c2-5d6e7f8a9b0c`.
  static String uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// The id the server sent ([remote], usually its `client_id`), or a new
  /// one when it sent none.
  static String orNew(Object? remote) {
    final value = remote?.toString();
    return value == null || value.isEmpty ? uuid() : value;
  }

  /// `<category id>:<name>`, shared with the server's default subcategories.
  static String subcategoryId(String categoryId, String name) =>
      '$categoryId:$name';
}
