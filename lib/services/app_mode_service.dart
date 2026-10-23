import 'package:sqflite/sqflite.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'sync_service.dart';

/// How the app stores its data.
///
/// - [local]: everything stays in the on-device SQLite database; no account,
///   no network calls.
/// - [server]: SQLite stays the source the UI reads from, but changes are
///   synced with the backend at [AppModeService.serverUrl].
enum AppMode { local, server }

class AppModeService {
  static const _modeKey = 'app_mode';
  static const _serverUrlKey = 'server_url';

  /// The chosen mode, or null on a fresh install that hasn't picked one.
  /// Read synchronously by the sync layer, so call [load] at startup.
  static AppMode? current;

  static bool get isServer => current == AppMode.server;

  final DatabaseService _dbService = DatabaseService();

  /// Load the persisted mode and server URL into memory.
  Future<AppMode?> load() async {
    final saved = await _read(_modeKey);
    current = AppMode.values.where((m) => m.name == saved).firstOrNull;

    final url = await _read(_serverUrlKey);
    ApiService.baseUrl = (url == null || url.isEmpty)
        ? ApiService.defaultBaseUrl
        : url;
    return current;
  }

  Future<void> setMode(AppMode mode) async {
    await _write(_modeKey, mode.name);
    current = mode;
  }

  /// Persist a custom backend URL; an empty value restores the default.
  Future<void> setServerUrl(String url) async {
    final normalized = ApiService.normalizeBaseUrl(url);
    await _write(_serverUrlKey, normalized);
    await SyncService.resetCursors();
    ApiService.baseUrl = normalized.isEmpty
        ? ApiService.defaultBaseUrl
        : normalized;
  }

  Future<String> getServerUrl() async => ApiService.baseUrl;

  Future<String?> _read(String key) async {
    final db = await _dbService.getDatabase();
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _write(String key, String value) async {
    final db = await _dbService.getDatabase();
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
