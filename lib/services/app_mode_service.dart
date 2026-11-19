import 'package:flutter/material.dart' show ThemeMode;
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
  static const _themeKey = 'theme_mode';

  /// The saved appearance, loaded by [load]; follows the system by default.
  static ThemeMode themeMode = ThemeMode.system;

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

    final theme = await _read(_themeKey);
    themeMode =
        ThemeMode.values.where((m) => m.name == theme).firstOrNull ??
        ThemeMode.system;
    return current;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _write(_themeKey, mode.name);
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

  /// Settings key for the account whose data is on this device.
  static const accountKey = 'account';

  /// The account whose data is on this device (`username@server`), or null
  /// if it has only been used without one.
  Future<String?> account() => _read(accountKey);

  static String _accountId(String username) =>
      '$username@${ApiService.baseUrl}';

  /// Call on signing in as [username], before anything syncs. Another
  /// account's data must not show to, or upload into, this one, so it is
  /// cleared first. Data made without an account stays and uploads.
  Future<void> adoptAccount(String username) async {
    final next = _accountId(username);
    final previous = await account();
    if (previous != null && previous != next) {
      await _dbService.clearUserData();
    }
    await _write(accountKey, next);
  }

  /// Installs from before accounts were recorded: note the signed-in one.
  Future<void> rememberAccount(String username) async {
    if (await account() == null) await _write(accountKey, _accountId(username));
  }

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
