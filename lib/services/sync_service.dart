import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'app_mode_service.dart';
import 'sync_outbox.dart';
import '../models/expenses.dart';
import '../models/workouts.dart';
import 'package:sqflite/sqflite.dart'
    show ConflictAlgorithm, Database, DatabaseExecutor;

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

  Future<void>? _inFlight;
  bool _syncAgain = false;

  static const _cursorPrefix = 'last_sync_';

  /// Forget all pull cursors so the next sync does a full pull. Call when the
  /// account or server changes.
  static Future<void> resetCursors() async {
    final db = await DatabaseService().getDatabase();
    await db.delete(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['$_cursorPrefix%'],
    );
  }

  Future<String?> _cursor(String entity) async {
    final db = await _dbService.getDatabase();
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['$_cursorPrefix$entity'],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Record that everything changed before [startedAt] has been pulled. A
  /// few minutes of overlap absorbs clock skew; re-pulled rows are idempotent.
  Future<void> _saveCursor(String entity, DateTime startedAt) async {
    final db = await _dbService.getDatabase();
    await db.insert('settings', {
      'key': '$_cursorPrefix$entity',
      'value': startedAt
          .toUtc()
          .subtract(const Duration(minutes: 5))
          .toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Pull every page of [path], asking only for rows changed since the last
  /// successful pull of [entity]. A server that ignores `updated_after` just
  /// returns everything, which the merge logic handles.
  Future<List<dynamic>> _fetchAll(String path, String entity) async {
    final since = await _cursor(entity);
    final items = <dynamic>[];
    String? url = path;
    Map<String, dynamic>? query = since == null
        ? null
        : {'updated_after': since};

    for (var page = 0; url != null && page < 200; page++) {
      final response = await _apiService.get(url, queryParameters: query);
      query = null; // `next` links already carry the filter
      items.addAll(_extractRemoteList(response.data));
      final data = response.data;
      url = data is Map<String, dynamic> ? data['next'] as String? : null;
    }
    return items;
  }

  bool _isTombstone(Map data) =>
      data['is_deleted'] == true || data['deleted'] == true;

  /// If the server echoes back the `client_id` we sent, attach its id to the
  /// matching local row instead of inserting a duplicate (e.g. when a push
  /// succeeded but the response was lost). Returns true when linked.
  Future<bool> _linkByClientId(
    DatabaseExecutor db,
    String table,
    Map data,
  ) async {
    final clientId = data['client_id']?.toString();
    if (clientId == null || clientId.isEmpty) return false;

    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'uuid = ? AND remote_id IS NULL',
      whereArgs: [clientId],
    );
    if (rows.isEmpty) return false;

    await db.update(
      table,
      {'remote_id': data['id']},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
    return true;
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  /// Fires after every completed sync run, so screens can reload from the
  /// local database once pulled data has landed.
  Stream<void> get onSyncComplete => _syncComplete.stream;
  final _syncComplete = StreamController<void>.broadcast();

  /// Perform full sync. Overlapping calls share one run: two concurrent
  /// runs would both push the same rows and both insert the same pulled
  /// rows (duplicates). A call made mid-run queues one more pass and
  /// completes only after it, so awaiting callers always see fresh data.
  Future<void> performSync() {
    // Local mode never talks to a server.
    if (!AppModeService.isServer) return Future.value();
    final inFlight = _inFlight;
    if (inFlight != null) {
      _syncAgain = true;
      return inFlight;
    }
    return _inFlight = _drive().whenComplete(() => _inFlight = null);
  }

  Future<void> _drive() async {
    do {
      _syncAgain = false;
      if (!await isOnline()) return;
      await _runSync();
      _syncComplete.add(null);
    } while (_syncAgain);
  }

  Future<void> _runSync() async {
    debugPrint('Starting Sync...');
    try {
      // Replay queued deletes first so the pulls below can't resurrect them.
      await SyncOutbox.drain(_apiService);
      await _syncCatalog(); // categories/events first: transactions reference them
      await _syncExpenses();
      await _syncWorkouts();
      await _syncGroups();
      await _syncGroupMembers();
      await _syncGroupExpenses();
      await _syncSettlements();
      await _cleanupOldSyncedData(); // Keep local cache small
      debugPrint('Sync Completed successfully.');
    } catch (e) {
      debugPrint('Sync Failed: $e');
    }
  }

  /// Sync categories and events (blueprint reference data). Failures are
  /// logged and never block the transaction sync that follows.
  Future<void> _syncCatalog() async {
    final db = await _dbService.getDatabase();

    // Push locally-created events (client UUID is kept as the server id).
    for (final row in await db.query('events', where: 'is_synced = 0')) {
      try {
        await _apiService.post(
          ApiService.eventsPath,
          data: {
            'id': row['id'],
            'title': row['title'],
            'event_date': row['event_date'],
            'end_date': row['end_date'],
            'description': row['description'],
          },
        );
        await db.update(
          'events',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Failed to sync event ${row['id']}: $e');
      }
    }

    // Push custom categories ('local' owner marks them as unsynced).
    for (final row in await db.query(
      'categories',
      where: 'user_id = ?',
      whereArgs: ['local'],
    )) {
      try {
        final response = await _apiService.post(
          ApiService.categoriesPath,
          data: {
            'id': row['id'],
            'name': row['name'],
            'icon': row['icon'],
            'color': row['color'],
            'type': row['type'],
          },
        );
        await db.update(
          'categories',
          {'user_id': (response.data['user'] ?? 'synced').toString()},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Failed to sync category ${row['id']}: $e');
      }
    }

    // Pull categories.
    try {
      final started = DateTime.now();
      final remoteCategories = await _fetchAll(
        ApiService.categoriesPath,
        'categories',
      );
      for (final data in remoteCategories) {
        if (data['id'] == null || data['name'] == null) continue;
        await db.insert('categories', {
          'id': data['id'].toString(),
          'user_id': data['user']?.toString() ?? data['user_id']?.toString(),
          'name': data['name'],
          'icon': data['icon'],
          'color': data['color'],
          'type': data['type'] ?? 'expense',
          'is_default': (data['is_default'] == true) ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await _saveCursor('categories', started);
    } catch (e) {
      debugPrint('Failed to fetch categories from remote: $e');
    }

    // Pull events.
    try {
      final started = DateTime.now();
      final remoteEvents = await _fetchAll(ApiService.eventsPath, 'events');
      for (final data in remoteEvents) {
        if (data['id'] == null || data['title'] == null) continue;
        await db.insert('events', {
          'id': data['id'].toString(),
          'title': data['title'],
          'event_date': data['event_date'],
          'end_date': data['end_date'],
          'description': data['description'],
          'is_synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await _saveCursor('events', started);
    } catch (e) {
      debugPrint('Failed to fetch events from remote: $e');
    }
  }

  /// Sync Expenses
  Future<void> _syncExpenses() async {
    final db = await _dbService.getDatabase();

    // 1. Push unsynced local expenses to server
    final unsynced = await db.query('expenses', where: 'is_synced = 0');
    for (var map in unsynced) {
      final expense = Expense.fromMap(map);
      try {
        // A row that already has a server id was edited locally: update it
        // instead of creating a duplicate.
        final existingRemoteId = map['remote_id'];
        final payload = {...expense.toApi(), 'client_id': map['uuid']};
        final response = existingRemoteId != null
            ? await _apiService.put(
                '${ApiService.transactionsPath}$existingRemoteId/',
                data: payload,
              )
            : await _apiService.post(
                ApiService.transactionsPath,
                data: payload,
              );
        final remoteId = response.data['id'] ?? existingRemoteId;
        await db.update(
          'expenses',
          {'remote_id': remoteId, 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
      } catch (e) {
        debugPrint('Failed to sync expense ${map['id']}: $e');
      }
    }

    // 2. Fetch remote expenses and update local cache
    try {
      final started = DateTime.now();
      final remoteData = await _fetchAll(
        ApiService.transactionsPath,
        'transactions',
      );

      for (var data in remoteData) {
        final remoteId = data['id'];
        if (remoteId == null) continue;

        if (_isTombstone(data)) {
          await db.delete(
            'expenses',
            where: 'remote_id = ?',
            whereArgs: [remoteId],
          );
          continue;
        }

        final existing = await db.query(
          'expenses',
          where: 'remote_id = ?',
          whereArgs: [remoteId],
        );

        if (existing.isNotEmpty) {
          // Take server-side edits, but never overwrite unsynced local ones.
          if (existing.first['is_synced'] == 1) {
            await db.update(
              'expenses',
              _expenseFromRemote(
                data,
                localTimestamp: existing.first['timestamp'] as String?,
              ),
              where: 'remote_id = ?',
              whereArgs: [remoteId],
            );
          }
          continue;
        }

        if (await _linkByClientId(db, 'expenses', data)) continue;

        // Not known locally (matched by remote_id / client_id above):
        // insert it. Never match on the local primary key, which is an
        // unrelated autoincrement id that can collide with the server's.
        final expenseMap = _expenseFromRemote(data);
        expenseMap['uuid'] = data['client_id'];
        await db.insert('expenses', expenseMap);
      }
      await _saveCursor('transactions', started);
    } catch (e) {
      debugPrint('Failed to fetch expenses from remote: $e');
    }
  }

  /// Sync Workouts
  Future<void> _syncWorkouts() async {
    final db = await _dbService.getDatabase();

    // 1. Push unsynced local workouts
    final unsynced = await db.query('workouts', where: 'is_synced = 0');
    for (var map in unsynced) {
      final workoutId = map['id'];

      // Load exercises and sets for this workout
      final exercises = await _loadFullWorkoutData(workoutId as int);
      final workout = Workout.fromMap(map).copyWith(exercises: exercises);

      try {
        // The server keeps exercises and sets nested in the workout, so the
        // whole session is sent: POST the first time, PUT once it has an id.
        final existingRemoteId = map['remote_id'];
        final payload = {...workout.toApi(), 'client_id': map['uuid']};
        final response = existingRemoteId == null
            ? await _apiService.post('fitness/workouts/', data: payload)
            : await _apiService.put(
                'fitness/workouts/$existingRemoteId/',
                data: payload,
              );
        final remoteId = response.data['id'] ?? existingRemoteId;

        // A set logged while the request was in flight must not be marked
        // synced; leave it dirty so the next sync pushes it.
        final after = await _loadFullWorkoutData(workoutId);
        final unchanged =
            jsonEncode(payload['exercises']) ==
            jsonEncode(after.map((e) => e.toApi()).toList());

        await db.update(
          'workouts',
          {'remote_id': remoteId, 'is_synced': unchanged ? 1 : 0},
          where: 'id = ?',
          whereArgs: [workoutId],
        );
      } catch (e) {
        debugPrint('Failed to sync workout $workoutId: $e');
      }
    }

    // 2. Fetch remote workouts
    try {
      final started = DateTime.now();
      final remoteData = await _fetchAll('fitness/workouts/', 'workouts');

      for (var data in remoteData) {
        final remoteId = data['id'];
        if (remoteId == null) continue;

        if (_isTombstone(data)) {
          await db.delete(
            'workouts',
            where: 'remote_id = ?',
            whereArgs: [remoteId],
          );
          continue;
        }

        final existing = await db.query(
          'workouts',
          where: 'remote_id = ?',
          whereArgs: [remoteId],
        );

        if (existing.isNotEmpty) {
          // Take edits made on another device, unless this one has
          // unpushed changes of its own (last write wins on push).
          if (existing.first['is_synced'] == 1) {
            await _updateRemoteWorkoutLocally(
              db,
              existing.first['id'] as int,
              data,
            );
          }
          continue;
        }

        if (!await _linkByClientId(db, 'workouts', data)) {
          // Save remote workout and its children locally
          await _saveRemoteWorkoutLocally(data);
        }
      }
      await _saveCursor('workouts', started);
    } catch (e) {
      debugPrint('Failed to fetch workouts from remote: $e');
    }
  }

  /// The server returns UTC; local queries compare local ISO strings.
  static String? _localTimestamp(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed?.toLocal().toIso8601String() ?? raw?.toString();
  }

  Future<List<Exercise>> _loadFullWorkoutData(int workoutId) async {
    final db = await _dbService.getDatabase();
    final exerciseMaps = await db.query(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'id ASC',
    );

    final exercises = <Exercise>[];
    for (var exMap in exerciseMaps) {
      final setMaps = await db.query(
        'sets',
        where: 'exercise_id = ?',
        whereArgs: [exMap['id']],
        orderBy: 'set_number ASC',
      );
      final sets = setMaps.map((s) => SetData.fromMap(s)).toList();
      exercises.add(Exercise.fromMap(exMap).copyWith(sets: sets));
    }
    return exercises;
  }

  Future<void> _saveRemoteWorkoutLocally(Map<String, dynamic> data) async {
    final db = await _dbService.getDatabase();
    final workoutMap = {
      'type': data['type'],
      'timestamp': _localTimestamp(data['timestamp']),
      'notes': data['notes'],
      'uuid': data['client_id'],
      'remote_id': data['id'],
      'is_synced': 1,
    };

    final localWorkoutId = await db.insert('workouts', workoutMap);
    await _insertRemoteExercises(db, localWorkoutId, data['exercises']);
  }

  /// Refresh a synced local workout from the server's copy. Children are
  /// replaced only when they actually differ, so our own push echoing back
  /// doesn't reshuffle local set ids mid-session.
  Future<void> _updateRemoteWorkoutLocally(
    DatabaseExecutor db,
    int localWorkoutId,
    Map<String, dynamic> data,
  ) async {
    await db.update(
      'workouts',
      {
        'type': data['type'],
        'timestamp': _localTimestamp(data['timestamp']),
        'notes': data['notes'],
      },
      where: 'id = ?',
      whereArgs: [localWorkoutId],
    );

    final remote = data['exercises'];
    if (remote is! List) return;
    final local = await _loadFullWorkoutData(localWorkoutId);
    final remoteContent = remote
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => {
            'name': e['name'],
            'muscle_group': e['muscle_group'],
            'sets': [
              for (final s in (e['sets'] as List? ?? const []))
                if (s is Map<String, dynamic>)
                  {
                    'set_number': s['set_number'],
                    'weight': (double.tryParse(s['weight'].toString()) ?? 0.0)
                        .toString(),
                    'reps': s['reps'],
                    'is_completed': s['is_completed'] == true,
                  },
            ],
          },
        )
        .toList();
    final localContent = local.map((e) => e.toApi()).toList();
    if (jsonEncode(remoteContent) == jsonEncode(localContent)) return;

    // Sets cascade-delete with their exercises.
    await db.delete(
      'exercises',
      where: 'workout_id = ?',
      whereArgs: [localWorkoutId],
    );
    await _insertRemoteExercises(db, localWorkoutId, remote);
  }

  Future<void> _insertRemoteExercises(
    DatabaseExecutor db,
    int localWorkoutId,
    Object? exercises,
  ) async {
    if (exercises is List) {
      for (final exData in exercises) {
        if (exData is! Map<String, dynamic>) continue;

        final exMap = {
          'workout_id': localWorkoutId,
          'name': exData['name'],
          'muscle_group': exData['muscle_group'],
          'remote_id': exData['id'],
          'is_synced': 1,
        };

        final localExId = await db.insert('exercises', exMap);

        final sets = exData['sets'];
        if (sets is List) {
          for (final setData in sets) {
            if (setData is! Map<String, dynamic>) continue;

            final sMap = {
              'exercise_id': localExId,
              'set_number': setData['set_number'],
              'weight': double.tryParse(setData['weight'].toString()) ?? 0.0,
              'reps': setData['reps'],
              'is_completed': setData['is_completed'] == true ? 1 : 0,
              'remote_id': setData['id'],
              'is_synced': 1,
            };
            await db.insert('sets', sMap);
          }
        }
      }
    }
  }

  List<dynamic> _extractRemoteList(dynamic data) {
    if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        return results;
      }
      return const [];
    }

    if (data is List) {
      return data;
    }

    return const [];
  }

  /// Accepts blueprint `transactions` JSON (txn_date/note/category uuid) and
  /// falls back to the legacy shape (timestamp/description/category name).
  /// The server only stores `txn_date` (a calendar day), but local queries
  /// compare full ISO timestamps, so never store the bare date. Keep the
  /// local time when the day is unchanged, else use the server's
  /// `created_at` time on that day, else local midnight.
  static String _timestampFromRemote(
    Map<String, dynamic> data,
    String? localTimestamp,
  ) {
    final raw = (data['txn_date'] ?? data['timestamp'])?.toString();
    final remote = raw == null ? null : DateTime.tryParse(raw);
    if (remote == null) {
      return localTimestamp ?? DateTime.now().toIso8601String();
    }
    // A full timestamp from the server (legacy `timestamp`) is already fine.
    if (raw!.length > 10) return remote.toIso8601String();

    final day = DateTime(remote.year, remote.month, remote.day);
    bool sameDay(DateTime t) =>
        t.year == day.year && t.month == day.month && t.day == day.day;

    final local = localTimestamp == null
        ? null
        : DateTime.tryParse(localTimestamp);
    if (local != null && sameDay(local)) return local.toIso8601String();

    final created = DateTime.tryParse(
      data['created_at']?.toString() ?? '',
    )?.toLocal();
    if (created != null && sameDay(created)) {
      return DateTime(
        day.year,
        day.month,
        day.day,
        created.hour,
        created.minute,
        created.second,
      ).toIso8601String();
    }
    return day.toIso8601String();
  }

  Map<String, dynamic> _expenseFromRemote(
    Map<String, dynamic> data, {
    String? localTimestamp,
  }) {
    final rawCategory = data['category'] ?? data['category_id'];
    final categoryId = data['category_id'] ?? data['category'];
    final legacyName = rawCategory is String && !rawCategory.contains('-')
        ? rawCategory
        : null;
    final matched = defaultCategories.where((c) => c.id == categoryId);
    final bucket =
        legacyName ??
        (matched.isNotEmpty
            ? matched.first.legacy.name
            : ExpenseCategory.other.name);

    return {
      'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
      'category': bucket,
      'timestamp': _timestampFromRemote(data, localTimestamp),
      'description': data['note'] ?? data['description'],
      'type': data['type'] ?? 'expense',
      'category_id': legacyName == null ? categoryId?.toString() : null,
      'subcategory_id': (data['subcategory_id'] ?? data['subcategory'])
          ?.toString(),
      'event_id': (data['event_id'] ?? data['event'])?.toString(),
      'payment_method': data['payment_method'],
      'attachment_url': data['attachment_url'],
      'remote_id': data['id'],
      'is_synced': 1,
    };
  }

  /// Sync Groups (push new/renamed groups, pull groups + memberships)
  Future<void> _syncGroups() async {
    final db = await _dbService.getDatabase();

    final unsynced = await db.query('groups', where: 'is_synced = 0');
    for (var map in unsynced) {
      try {
        final response = await _apiService.post(
          'groups/groups/',
          data: {
            'name': map['name'],
            'icon': map['icon'],
            'client_id': map['uuid'],
          },
        );
        final remoteId = response.data['id'];
        await db.update(
          'groups',
          {'remote_id': remoteId, 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        // The owner membership was auto-created server-side; reconcile it.
        final remoteMemberships = response.data['memberships'];
        if (remoteMemberships is List) {
          await _reconcileMemberships(map['id'] as int, remoteMemberships);
        }
      } catch (e) {
        debugPrint('Failed to sync group ${map['id']}: $e');
      }
    }

    try {
      final started = DateTime.now();
      final remoteGroups = await _fetchAll('groups/groups/', 'groups');

      for (var data in remoteGroups) {
        final remoteId = data['id'];
        if (remoteId == null) continue;

        var existing = await db.query(
          'groups',
          where: 'remote_id = ?',
          whereArgs: [remoteId],
        );
        if (existing.isEmpty && await _linkByClientId(db, 'groups', data)) {
          existing = await db.query(
            'groups',
            where: 'remote_id = ?',
            whereArgs: [remoteId],
          );
        }
        int localGroupId;
        if (existing.isEmpty) {
          localGroupId = await db.insert('groups', {
            'uuid': data['client_id'],
            'remote_id': remoteId,
            'name': data['name'],
            'icon': data['icon'],
            'created_at': data['created_at'],
            'is_synced': 1,
          });
        } else {
          localGroupId = existing.first['id'] as int;
          await db.update(
            'groups',
            {'name': data['name'], 'icon': data['icon']},
            where: 'id = ?',
            whereArgs: [localGroupId],
          );
        }

        final memberships = data['memberships'];
        if (memberships is List) {
          await _reconcileMemberships(localGroupId, memberships);
        }
      }
      await _saveCursor('groups', started);
    } catch (e) {
      debugPrint('Failed to fetch groups from remote: $e');
    }
  }

  /// Reconcile a group's memberships against the server's list, inserting
  /// any member rows we don't have locally yet and stamping remote ids.
  Future<void> _reconcileMemberships(
    int localGroupId,
    List remoteMemberships,
  ) async {
    final db = await _dbService.getDatabase();

    for (final m in remoteMemberships) {
      if (m is! Map<String, dynamic>) continue;
      final remoteMemberId = m['id'];

      final existing = await db.query(
        'group_members',
        where: 'remote_id = ? AND group_id = ?',
        whereArgs: [remoteMemberId, localGroupId],
      );

      if (existing.isNotEmpty) {
        continue;
      }

      // A member with the same username may exist locally without a
      // remote_id yet (e.g. the owner's own membership row).
      var localMatch = await db.query(
        'group_members',
        where: 'group_id = ? AND username = ? AND remote_id IS NULL',
        whereArgs: [localGroupId, m['username']],
      );
      // A group made before signing in has a local owner named 'Me'; the
      // server's owner is the account that pushed it, i.e. the same person.
      if (localMatch.isEmpty && m['role'] == 'owner') {
        localMatch = await db.query(
          'group_members',
          where: "group_id = ? AND role = 'owner' AND remote_id IS NULL",
          whereArgs: [localGroupId],
        );
      }

      if (localMatch.isNotEmpty) {
        await db.update(
          'group_members',
          {
            'remote_id': remoteMemberId,
            'is_synced': 1,
            'user_id': m['user'],
            'username': m['username'],
          },
          where: 'id = ?',
          whereArgs: [localMatch.first['id']],
        );
      } else {
        await db.insert('group_members', {
          'remote_id': remoteMemberId,
          'group_id': localGroupId,
          'user_id': m['user'],
          'username': m['username'],
          'email': m['email'],
          'role': m['role'],
          'is_synced': 1,
        });
      }
    }
  }

  /// Push locally-added members (invites) that haven't reached the server.
  Future<void> _syncGroupMembers() async {
    final db = await _dbService.getDatabase();
    await _mergeOrphanOwners(db);

    // Members the server already rejected (no such user) are not retried.
    final unsynced = await db.rawQuery('''
      SELECT gm.*, g.remote_id AS group_remote_id
      FROM group_members gm
      JOIN groups g ON g.id = gm.group_id
      WHERE gm.is_synced = 0 AND g.remote_id IS NOT NULL
        AND gm.sync_error IS NULL
    ''');

    for (var map in unsynced) {
      final groupRemoteId = map['group_remote_id'];
      try {
        final response = await _apiService.post(
          'groups/groups/$groupRemoteId/add-member/',
          data: {'username': map['username']},
        );
        await db.update(
          'group_members',
          {
            'remote_id': response.data['id'],
            'user_id': response.data['user'],
            'is_synced': 1,
          },
          where: 'id = ?',
          whereArgs: [map['id']],
        );
      } on DioException catch (e) {
        // 400 = the server can't add them (e.g. no account with that
        // username). Record why and stop retrying; other errors retry.
        if (e.response?.statusCode == 400) {
          final data = e.response?.data;
          final reason = data is Map && data['username'] is List
              ? (data['username'] as List).join(' ')
              : 'Could not add this member.';
          await db.update(
            'group_members',
            {'sync_error': reason},
            where: 'id = ?',
            whereArgs: [map['id']],
          );
        }
        debugPrint('Failed to sync group member ${map['id']}: $e');
      } catch (e) {
        debugPrint('Failed to sync group member ${map['id']}: $e');
      }
    }
  }

  /// Groups pushed by older builds got a separate server-owner row while
  /// the local 'Me' owner kept no server id, which blocked every expense
  /// paid by or split with 'Me'. Fold such orphans into the linked owner.
  Future<void> _mergeOrphanOwners(DatabaseExecutor db) async {
    final pairs = await db.rawQuery('''
      SELECT orphan.id AS orphan_id, linked.id AS linked_id
      FROM group_members orphan
      JOIN group_members linked
        ON linked.group_id = orphan.group_id
       AND linked.role = 'owner' AND linked.remote_id IS NOT NULL
      WHERE orphan.role = 'owner' AND orphan.remote_id IS NULL
    ''');
    for (final pair in pairs) {
      final orphan = pair['orphan_id'];
      final linked = pair['linked_id'];
      if (db is Database) {
        await db.transaction((txn) => _repointMember(txn, orphan, linked));
      } else {
        await _repointMember(db, orphan, linked);
      }
    }
  }

  Future<void> _repointMember(
    DatabaseExecutor db,
    Object? from,
    Object? to,
  ) async {
    // Repoint references first: deleting the row cascades to them.
    for (final (table, column) in const [
      ('group_expenses', 'payer_member_id'),
      ('group_expense_splits', 'member_id'),
      ('settlements', 'from_member_id'),
      ('settlements', 'to_member_id'),
    ]) {
      await db.update(
        table,
        {column: to},
        where: '$column = ?',
        whereArgs: [from],
      );
    }
    await db.delete('group_members', where: 'id = ?', whereArgs: [from]);
  }

  /// Sync group expenses (with their splits), translating local ids to
  /// remote ids for group/payer/member references.
  Future<void> _syncGroupExpenses() async {
    final db = await _dbService.getDatabase();

    final unsynced = await db.query('group_expenses', where: 'is_synced = 0');
    for (var map in unsynced) {
      final localExpenseId = map['id'] as int;

      final groupRow = await db.query(
        'groups',
        where: 'id = ?',
        whereArgs: [map['group_id']],
      );
      final payerRow = await db.query(
        'group_members',
        where: 'id = ?',
        whereArgs: [map['payer_member_id']],
      );
      if (groupRow.isEmpty || payerRow.isEmpty) continue;

      final groupRemoteId = groupRow.first['remote_id'];
      final payerRemoteId = payerRow.first['remote_id'];
      if (groupRemoteId == null || payerRemoteId == null) continue;

      final splitRows = await db.query(
        'group_expense_splits',
        where: 'expense_id = ?',
        whereArgs: [localExpenseId],
      );
      final splitPayload = <Map<String, dynamic>>[];
      var allMembersSynced = true;

      for (final split in splitRows) {
        final memberRow = await db.query(
          'group_members',
          where: 'id = ?',
          whereArgs: [split['member_id']],
        );
        final memberRemoteId = memberRow.isNotEmpty
            ? memberRow.first['remote_id']
            : null;
        if (memberRemoteId == null) {
          allMembersSynced = false;
          break;
        }
        splitPayload.add({
          'member': memberRemoteId,
          'share_amount': split['share_amount'],
        });
      }

      if (!allMembersSynced) continue;

      try {
        final response = await _apiService.post(
          'groups/group-expenses/',
          data: {
            'group': groupRemoteId,
            'payer': payerRemoteId,
            'amount': map['amount'],
            'category': map['category'],
            'description': map['description'],
            'timestamp': map['timestamp'],
            'receipt_url': map['receipt_url'],
            'split_type': map['split_type'],
            'client_id': map['uuid'],
            'splits': splitPayload,
          },
        );

        await db.update(
          'group_expenses',
          {'remote_id': response.data['id'], 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [localExpenseId],
        );

        final remoteSplits = response.data['splits'];
        if (remoteSplits is List) {
          for (final rs in remoteSplits) {
            if (rs is! Map<String, dynamic>) continue;
            await db.update(
              'group_expense_splits',
              {'remote_id': rs['id']},
              where:
                  'expense_id = ? AND member_id = (SELECT id FROM group_members WHERE remote_id = ?)',
              whereArgs: [localExpenseId, rs['member']],
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to sync group expense $localExpenseId: $e');
      }
    }

    try {
      final started = DateTime.now();
      final remoteData = await _fetchAll(
        'groups/group-expenses/',
        'group_expenses',
      );

      for (var data in remoteData) {
        final remoteId = data['id'];
        if (remoteId == null) continue;

        final existing = await db.query(
          'group_expenses',
          where: 'remote_id = ?',
          whereArgs: [remoteId],
        );
        if (existing.isNotEmpty) continue;
        if (await _linkByClientId(db, 'group_expenses', data)) continue;

        final groupRow = await db.query(
          'groups',
          where: 'remote_id = ?',
          whereArgs: [data['group']],
        );
        final payerRow = await db.query(
          'group_members',
          where: 'remote_id = ?',
          whereArgs: [data['payer']],
        );
        if (groupRow.isEmpty || payerRow.isEmpty) continue;

        final localExpenseId = await db.insert('group_expenses', {
          'uuid': data['client_id'],
          'remote_id': remoteId,
          'group_id': groupRow.first['id'],
          'payer_member_id': payerRow.first['id'],
          'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
          'category': data['category'],
          'description': data['description'],
          'timestamp': data['timestamp'],
          'receipt_url': data['receipt_url'],
          'split_type': data['split_type'],
          'is_synced': 1,
        });

        final splits = data['splits'];
        if (splits is List) {
          for (final s in splits) {
            if (s is! Map<String, dynamic>) continue;
            final memberRow = await db.query(
              'group_members',
              where: 'remote_id = ?',
              whereArgs: [s['member']],
            );
            if (memberRow.isEmpty) continue;
            await db.insert('group_expense_splits', {
              'remote_id': s['id'],
              'expense_id': localExpenseId,
              'member_id': memberRow.first['id'],
              'share_amount':
                  double.tryParse(s['share_amount'].toString()) ?? 0.0,
            });
          }
        }
      }
      await _saveCursor('group_expenses', started);
    } catch (e) {
      debugPrint('Failed to fetch group expenses from remote: $e');
    }
  }

  /// Sync settlements, translating local ids to remote ids.
  Future<void> _syncSettlements() async {
    final db = await _dbService.getDatabase();

    final unsynced = await db.query('settlements', where: 'is_synced = 0');
    for (var map in unsynced) {
      final groupRow = await db.query(
        'groups',
        where: 'id = ?',
        whereArgs: [map['group_id']],
      );
      final fromRow = await db.query(
        'group_members',
        where: 'id = ?',
        whereArgs: [map['from_member_id']],
      );
      final toRow = await db.query(
        'group_members',
        where: 'id = ?',
        whereArgs: [map['to_member_id']],
      );
      if (groupRow.isEmpty || fromRow.isEmpty || toRow.isEmpty) continue;

      final groupRemoteId = groupRow.first['remote_id'];
      final fromRemoteId = fromRow.first['remote_id'];
      final toRemoteId = toRow.first['remote_id'];
      if (groupRemoteId == null || fromRemoteId == null || toRemoteId == null) {
        continue;
      }

      try {
        final response = await _apiService.post(
          'groups/settlements/',
          data: {
            'group': groupRemoteId,
            'from_member': fromRemoteId,
            'to_member': toRemoteId,
            'amount': map['amount'],
            'timestamp': map['timestamp'],
            'client_id': map['uuid'],
          },
        );
        await db.update(
          'settlements',
          {'remote_id': response.data['id'], 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
      } catch (e) {
        debugPrint('Failed to sync settlement ${map['id']}: $e');
      }
    }

    try {
      final started = DateTime.now();
      final remoteData = await _fetchAll('groups/settlements/', 'settlements');

      for (var data in remoteData) {
        final remoteId = data['id'];
        if (remoteId == null) continue;

        final existing = await db.query(
          'settlements',
          where: 'remote_id = ?',
          whereArgs: [remoteId],
        );
        if (existing.isNotEmpty) continue;
        if (await _linkByClientId(db, 'settlements', data)) continue;

        final groupRow = await db.query(
          'groups',
          where: 'remote_id = ?',
          whereArgs: [data['group']],
        );
        final fromRow = await db.query(
          'group_members',
          where: 'remote_id = ?',
          whereArgs: [data['from_member']],
        );
        final toRow = await db.query(
          'group_members',
          where: 'remote_id = ?',
          whereArgs: [data['to_member']],
        );
        if (groupRow.isEmpty || fromRow.isEmpty || toRow.isEmpty) continue;

        await db.insert('settlements', {
          'uuid': data['client_id'],
          'remote_id': remoteId,
          'group_id': groupRow.first['id'],
          'from_member_id': fromRow.first['id'],
          'to_member_id': toRow.first['id'],
          'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
          'timestamp': data['timestamp'],
          'is_synced': 1,
        });
      }
      await _saveCursor('settlements', started);
    } catch (e) {
      debugPrint('Failed to fetch settlements from remote: $e');
    }
  }

  /// Cleanup synced data older than 30 days to keep the local cache small
  Future<void> _cleanupOldSyncedData() async {
    final db = await _dbService.getDatabase();
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();

    // Only delete data that HAS been synced to the server
    await db.delete(
      'expenses',
      where: 'is_synced = 1 AND timestamp < ?',
      whereArgs: [cutoff],
    );
    await db.delete(
      'workouts',
      where: 'is_synced = 1 AND timestamp < ?',
      whereArgs: [cutoff],
    );
    // Exercises and sets will be deleted automatically due to CASCADE in workouts

    debugPrint('Local cache cleaned up. Records older than 30 days removed.');
  }
}
