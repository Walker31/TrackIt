import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as path;

/// Database Service
/// Handles all database operations using SQLite
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _initialized = false;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// Initialize sqflite (must be called once at app startup)
  static Future<void> initialize() async {
    if (_initialized) return;
    
    if (kIsWeb) {
      // Initialize sqflite for Web
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows || 
               defaultTargetPlatform == TargetPlatform.linux || 
               defaultTargetPlatform == TargetPlatform.macOS) {
      // Initialize sqflite FFI for desktop
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    _initialized = true;
  }

  /// Get database instance
  Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    await initialize(); // Ensure initialization
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final dbPath = path.join(databasePath, 'trackit.db');

    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: _createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await db.insert('settings', {'key': 'monthly_budget', 'value': '50000'});
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS routines (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      },
    );
  }

  /// Create all database tables
  Future<void> _createTables(Database db, int version) async {
    // Expenses table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Workout sessions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Exercises table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE
      )
    ''');

    // Sets table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        is_completed INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Routines table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Routine Exercises table
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

    // Settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default settings
    await db.insert('settings', {'key': 'monthly_budget', 'value': '50000'});

    // Create indexes for better query performance
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_timestamp ON expenses(timestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_workouts_timestamp ON workouts(timestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_workouts_type ON workouts(type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_exercises_workout_id ON exercises(workout_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sets_exercise_id ON sets(exercise_id)');
  }

  /// Close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    final db = await getDatabase();
    await db.delete('sets');
    await db.delete('exercises');
    await db.delete('workouts');
    await db.delete('expenses');
  }

  /// Database schema documentation
  static const String schemaDocumentation = '''
  DATABASE SCHEMA:
  
  1. EXPENSES TABLE
     - id: Primary key (auto-increment)
     - amount: Double, transaction amount
     - category: String, expense category
     - timestamp: ISO8601 datetime of transaction
     - description: Optional transaction notes
     - created_at: Auto-generated timestamp
  
  2. WORKOUTS TABLE
     - id: Primary key (auto-increment)
     - type: String, workout type (push/pull/legs)
     - timestamp: ISO8601 datetime of workout
     - notes: Optional workout notes
     - created_at: Auto-generated timestamp
  
  3. EXERCISES TABLE
     - id: Primary key (auto-increment)
     - workout_id: Foreign key to workouts
     - name: String, exercise name
     - muscle_group: String, targeted muscle group
     - created_at: Auto-generated timestamp
  
  4. SETS TABLE
     - id: Primary key (auto-increment)
     - exercise_id: Foreign key to exercises
     - set_number: Integer, set number (1, 2, 3, etc.)
     - weight: Double, weight in kg
     - reps: Integer, number of repetitions
     - is_completed: Boolean, completion status
     - created_at: Auto-generated timestamp
  ''';
}
