import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/finance/category.dart';
import 'sync_outbox.dart';

/// Central SQLite service for the app.
///
/// This service owns database initialization, schema creation, and all
/// migrations so older installs can safely upgrade without losing data.
class DatabaseService {
  static const int _databaseVersion = 6;
  static const String _databaseName = 'trackit.db';
  static const String _monthlyBudgetKey = 'monthly_budget';
  static const String _defaultMonthlyBudget = '50000';

  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _initialized = false;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Initialize the database factory once at app startup.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      // SharedWorker isn't reliably supported across all browser shells
      // (e.g. some embedded/Electron-based browsers); the basic dedicated
      // Worker variant works everywhere SharedWorker would.
      databaseFactory = databaseFactoryFfiWebBasicWebWorker;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _initialized = true;
  }

  /// Returns the singleton database instance.
  Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    await initialize();
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, _databaseName);

    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: _configureDatabase,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onOpen: _repairSchema,
    );
  }

  Future<void> _configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDatabase(Database db, int version) async {
    await _createSchema(db);
    await _seedDefaultSettings(db);
    await _createIndexes(db);
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await db.transaction((txn) async {
      if (oldVersion < 2) {
        await _migrateToV2(txn);
      }

      if (oldVersion < 3) {
        await _migrateToV3(txn);
      }

      if (oldVersion < 4) {
        await _migrateToV4(txn);
      }

      if (oldVersion < 5) {
        await _migrateToV5(txn);
      }

      if (oldVersion < 6) {
        await _migrateToV6(txn);
      }

      await _seedDefaultSettings(txn);
      await _createIndexes(txn);
    });
  }

  Future<void> _repairSchema(Database db) async {
    await db.transaction((txn) async {
      await _ensureCompatibleSchema(txn);
      await _seedDefaultSettings(txn);
      await _createIndexes(txn);
    });
  }

  Future<void> _migrateToV2(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateToV3(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS routine_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        sets_count INTEGER NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateToV4(DatabaseExecutor db) async {
    await _ensureCompatibleSchema(db);
  }

  Future<void> _migrateToV5(DatabaseExecutor db) async {
    await _createGroupTables(db);
  }

  Future<void> _migrateToV6(DatabaseExecutor db) async {
    await _ensureBlueprintSchema(db);
  }

  /// PaisaPulse blueprint tables (categories, subcategories, events, budgets)
  /// and the extra `expenses` (transactions) columns. Idempotent.
  Future<void> _ensureBlueprintSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        remote_id TEXT,
        user_id TEXT,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('expense', 'income')),
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (user_id, name, type)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subcategories (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (category_id, name),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        is_synced INTEGER NOT NULL DEFAULT 0,
        title TEXT NOT NULL,
        event_date TEXT NOT NULL,
        end_date TEXT,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        month TEXT NOT NULL,
        limit_amount REAL NOT NULL CHECK (limit_amount > 0),
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (category_id, month),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    await _ensureColumn(
      db,
      'expenses',
      'type',
      "TEXT NOT NULL DEFAULT 'expense'",
    );
    await _ensureColumn(db, 'expenses', 'category_id', 'TEXT');
    await _ensureColumn(db, 'expenses', 'subcategory_id', 'TEXT');
    await _ensureColumn(db, 'expenses', 'event_id', 'TEXT');
    await _ensureColumn(db, 'expenses', 'payment_method', 'TEXT');
    await _ensureColumn(db, 'expenses', 'attachment_url', 'TEXT');
    await _ensureColumn(db, 'expenses', 'updated_at', 'TEXT');

    for (final c in defaultCategories) {
      await db.insert(
        'categories',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final s in defaultSubcategories) {
      await db.insert(
        'subcategories',
        s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Backfill legacy rows (category enum name -> default category).
    const legacyToDefault = {
      'food': 'Food & Dining',
      'transport': 'Transport',
      'shopping': 'Shopping',
      'health': 'Health & Fitness',
      'entertainment': 'Entertainment',
      'other': 'Miscellaneous',
    };
    for (final e in legacyToDefault.entries) {
      final id = defaultCategories.firstWhere((c) => c.name == e.value).id;
      await db.update(
        'expenses',
        {'category_id': id},
        where: 'category_id IS NULL AND category = ?',
        whereArgs: [e.key],
      );
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON expenses(category_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_event_id ON expenses(event_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subcategories_category ON subcategories(category_id)',
    );
  }

  Future<void> _ensureCompatibleSchema(DatabaseExecutor db) async {
    await _createGroupTables(db);
    await _ensureBlueprintSchema(db);
    await SyncOutbox.ensureSchema(db);

    await _ensureColumn(db, 'expenses', 'remote_id', 'INTEGER');
    await _ensureColumn(
      db,
      'expenses',
      'is_synced',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _ensureColumn(db, 'workouts', 'remote_id', 'INTEGER');
    await _ensureColumn(
      db,
      'workouts',
      'is_synced',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _ensureColumn(db, 'exercises', 'remote_id', 'INTEGER');
    await _ensureColumn(
      db,
      'exercises',
      'is_synced',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _ensureColumn(db, 'sets', 'remote_id', 'INTEGER');
    await _ensureColumn(db, 'sets', 'is_synced', 'INTEGER NOT NULL DEFAULT 0');

    await _ensureColumn(db, 'routines', 'remote_id', 'INTEGER');
    await _ensureColumn(
      db,
      'routines',
      'is_synced',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _backfillSyncFlags(db, 'expenses');
    await _backfillSyncFlags(db, 'workouts');
    await _backfillSyncFlags(db, 'exercises');
    await _backfillSyncFlags(db, 'sets');
    await _backfillSyncFlags(db, 'routines');

    await _ensureIdentitySchema(db);
  }

  /// Tables that sync with the server and so need a stable client-generated
  /// identity (`uuid`) and a change timestamp (`updated_at`).
  static const _syncedTables = [
    'expenses',
    'workouts',
    'exercises',
    'sets',
    'routines',
    'groups',
    'group_members',
    'group_expenses',
    'settlements',
  ];

  /// Random v4 UUID generated by SQLite itself, so every insert path gets one
  /// without each call site having to supply it.
  static const _uuidSql =
      "lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || "
      "substr(hex(randomblob(2)), 2) || '-' || "
      "substr('89ab', abs(random()) % 4 + 1, 1) || "
      "substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))";

  static const _nowSql = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

  /// Adds `uuid` / `updated_at`, backfills existing rows once, and installs
  /// triggers that fill them on insert and bump `updated_at` on local edits.
  /// Idempotent.
  Future<void> _ensureIdentitySchema(DatabaseExecutor db) async {
    for (final t in _syncedTables) {
      await _ensureColumn(db, t, 'uuid', 'TEXT');
      await _ensureColumn(db, t, 'updated_at', 'TEXT');

      // Backfill before the triggers exist so it doesn't count as an edit.
      // Not every synced table has a created_at (e.g. group_members).
      final created = await _columnExists(db, t, 'created_at')
          ? 'COALESCE(created_at, $_nowSql)'
          : _nowSql;
      await db.execute(
        'UPDATE $t SET updated_at = $created WHERE updated_at IS NULL',
      );
      await db.execute('UPDATE $t SET uuid = $_uuidSql WHERE uuid IS NULL');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${t}_uuid ON $t(uuid)');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${t}_identity
        AFTER INSERT ON $t
        WHEN NEW.uuid IS NULL OR NEW.updated_at IS NULL
        BEGIN
          UPDATE $t
          SET uuid = COALESCE(NEW.uuid, $_uuidSql),
              updated_at = COALESCE(NEW.updated_at, $_nowSql)
          WHERE id = NEW.id;
        END
      ''');
      // Bump on edits, but not when sync merely flips is_synced 0 -> 1 or a
      // caller already set updated_at explicitly.
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${t}_touch
        AFTER UPDATE ON $t
        WHEN NEW.updated_at IS OLD.updated_at
          AND NOT (OLD.is_synced = 0 AND NEW.is_synced = 1)
        BEGIN
          UPDATE $t SET updated_at = $_nowSql WHERE id = NEW.id;
        END
      ''');
    }
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        workout_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        is_completed INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS routine_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        sets_count INTEGER NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');

    await _createGroupTables(db);
  }

  Future<void> _createGroupTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '💰',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        group_id INTEGER NOT NULL,
        user_id INTEGER,
        username TEXT NOT NULL,
        email TEXT,
        role TEXT NOT NULL DEFAULT 'member',
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        group_id INTEGER NOT NULL,
        payer_member_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        timestamp TEXT NOT NULL,
        receipt_url TEXT,
        split_type TEXT NOT NULL DEFAULT 'equal',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
        FOREIGN KEY (payer_member_id) REFERENCES group_members(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_expense_splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        expense_id INTEGER NOT NULL,
        member_id INTEGER NOT NULL,
        share_amount REAL NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES group_expenses(id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES group_members(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        group_id INTEGER NOT NULL,
        from_member_id INTEGER NOT NULL,
        to_member_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
        FOREIGN KEY (from_member_id) REFERENCES group_members(id) ON DELETE CASCADE,
        FOREIGN KEY (to_member_id) REFERENCES group_members(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_expenses_group_id ON group_expenses(group_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_expense_splits_expense_id ON group_expense_splits(expense_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_settlements_group_id ON settlements(group_id)',
    );
  }

  Future<void> _seedDefaultSettings(DatabaseExecutor db) async {
    await db.insert('settings', {
      'key': _monthlyBudgetKey,
      'value': _defaultMonthlyBudget,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_timestamp ON expenses(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_remote_id ON expenses(remote_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_is_synced ON expenses(is_synced)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workouts_timestamp ON workouts(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workouts_type ON workouts(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workouts_remote_id ON workouts(remote_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workouts_is_synced ON workouts(is_synced)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercises_workout_id ON exercises(workout_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercises_remote_id ON exercises(remote_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exercises_is_synced ON exercises(is_synced)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sets_exercise_id ON sets(exercise_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sets_remote_id ON sets(remote_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sets_is_synced ON sets(is_synced)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_routines_remote_id ON routines(remote_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_routines_is_synced ON routines(is_synced)',
    );
  }

  Future<void> _ensureColumn(
    DatabaseExecutor db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    if (await _columnExists(db, tableName, columnName)) {
      return;
    }

    await db.execute(
      'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
    );
  }

  Future<bool> _columnExists(
    DatabaseExecutor db,
    String tableName,
    String columnName,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    return rows.any((row) => row['name'] == columnName);
  }

  Future<void> _backfillSyncFlags(DatabaseExecutor db, String tableName) async {
    await db.update(tableName, {'is_synced': 0}, where: 'is_synced IS NULL');
  }

  /// Close the database connection.
  Future<void> closeDatabase() async {
    if (_database == null) {
      return;
    }

    await _database!.close();
    _database = null;
  }

  /// Clear user data from the local database.
  ///
  /// This is intended for testing and debugging only.
  Future<void> clearAllData() async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete(SyncOutbox.table);
      await txn.delete('routine_exercises');
      await txn.delete('routines');
      await txn.delete('sets');
      await txn.delete('exercises');
      await txn.delete('workouts');
      await txn.delete('expenses');
      await txn.delete('budgets');
      await txn.delete('events');
      await txn.delete('group_expense_splits');
      await txn.delete('settlements');
      await txn.delete('group_expenses');
      await txn.delete('group_members');
      await txn.delete('groups');
      await txn.delete(
        'settings',
        where: 'key NOT IN (?, ?, ?)',
        whereArgs: [_monthlyBudgetKey, 'app_mode', 'server_url'],
      );
    });

    await _seedDefaultSettings(db);
  }

  /// Database schema documentation.
  static const String schemaDocumentation = '''
  DATABASE SCHEMA:

  1. EXPENSES TABLE
     - id: Primary key (auto-increment)
     - remote_id: Remote sync identifier
     - is_synced: Sync state flag (0/1)
     - amount: Double, transaction amount
     - category: String, legacy expense bucket (derived from category_id)
     - timestamp: ISO8601 datetime of transaction (blueprint `txn_date`)
     - description: Optional transaction notes (blueprint `note`)
     - type: 'expense' | 'income'
     - category_id / subcategory_id / event_id: blueprint FKs (TEXT UUIDs)
     - payment_method: cash/card/upi/netbanking/wallet/other
     - attachment_url, updated_at
     - created_at: Auto-generated timestamp

  1b. CATEGORIES / SUBCATEGORIES / EVENTS / BUDGETS (PaisaPulse blueprint)
     - categories(id, user_id NULL=default, name, icon, color, type, is_default)
     - subcategories(id, category_id, name)
     - events(id, title, event_date, end_date, description)
     - budgets(id, category_id, month, limit_amount)

  2. WORKOUTS TABLE
     - id: Primary key (auto-increment)
     - remote_id: Remote sync identifier
     - is_synced: Sync state flag (0/1)
     - type: String, workout type (push/pull/legs)
     - timestamp: ISO8601 datetime of workout
     - notes: Optional workout notes
     - created_at: Auto-generated timestamp

  3. EXERCISES TABLE
     - id: Primary key (auto-increment)
     - remote_id: Remote sync identifier
     - is_synced: Sync state flag (0/1)
     - workout_id: Foreign key to workouts
     - name: String, exercise name
     - muscle_group: String, targeted muscle group
     - created_at: Auto-generated timestamp

  4. SETS TABLE
     - id: Primary key (auto-increment)
     - remote_id: Remote sync identifier
     - is_synced: Sync state flag (0/1)
     - exercise_id: Foreign key to exercises
     - set_number: Integer, set number (1, 2, 3, etc.)
     - weight: Double, weight in kg
     - reps: Integer, number of repetitions
     - is_completed: Boolean, completion status
     - created_at: Auto-generated timestamp

  5. ROUTINES TABLE
     - id: Primary key (auto-increment)
     - remote_id: Remote sync identifier
     - is_synced: Sync state flag (0/1)
     - name: String, routine name
     - type: String, routine type
     - created_at: Auto-generated timestamp

  6. ROUTINE_EXERCISES TABLE
     - id: Primary key (auto-increment)
     - routine_id: Foreign key to routines
     - name: String, exercise name
     - muscle_group: String, targeted muscle group
     - sets_count: Integer, planned sets
  ''';
}
