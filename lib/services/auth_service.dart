import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'app_mode_service.dart';
import 'sync_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final storage = const FlutterSecureStorage();

  /// Logs in and stores the tokens. Returns null on success, otherwise a
  /// message saying what went wrong (wrong password vs. server unreachable).
  Future<String?> login(String username, String password) async {
    try {
      final response = await _apiService.post(
        'auth/login/',
        data: {'username': username, 'password': password},
      );
      await storage.write(key: 'access_token', value: response.data['access']);
      await storage.write(
        key: 'refresh_token',
        value: response.data['refresh'],
      );
      await AppModeService().setMode(AppMode.server);
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        return 'Incorrect username or password.';
      }
      return _networkError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Creates the account, then logs in. Returns null on success, otherwise
  /// the server's reason (e.g. username taken) or a connection message.
  Future<String?> register(
    String username,
    String password,
    String email,
  ) async {
    try {
      await _apiService.post(
        'auth/register/',
        data: {'username': username, 'password': password, 'email': email},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return _firstFieldError(e.response?.data) ??
            'Registration failed. Check your details.';
      }
      return _networkError(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
    return login(username, password);
  }

  /// No response at all means the server couldn't be reached; 5xx means it
  /// failed. Neither is the user's fault, so say so.
  static String _networkError(DioException e) {
    final status = e.response?.statusCode;
    if (status != null && status >= 500) {
      return 'The server ran into a problem. Please try again shortly.';
    }
    if (status != null) {
      return 'The server rejected the request ($status).';
    }
    return "Can't reach the server. Check your connection or the server "
        'address in Server settings.';
  }

  /// DRF errors look like {"username": ["A user with that username..."]}.
  static String? _firstFieldError(Object? data) {
    if (data is Map) {
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }
    return null;
  }

  Future<void> logout() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: _profileKey);
    await SyncService.resetCursors();
  }

  static const _profileKey = 'cached_profile';

  /// Fetch the profile and cache it for offline start-up. Distinguishes a
  /// rejected token (`unauthorized`) from the server simply being unreachable.
  Future<({Map<String, dynamic>? profile, bool unauthorized})>
  fetchProfile() async {
    try {
      final response = await _apiService.get('auth/me/');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        await storage.write(key: _profileKey, value: jsonEncode(data));
        return (profile: data, unauthorized: false);
      }
      return (profile: null, unauthorized: false);
    } on DioException catch (e) {
      return (profile: null, unauthorized: e.response?.statusCode == 401);
    } catch (_) {
      return (profile: null, unauthorized: false);
    }
  }

  Future<Map<String, dynamic>?> getCachedProfile() async {
    final raw = await storage.read(key: _profileKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async =>
      (await fetchProfile()).profile;

  Future<String?> getAccessToken() async {
    return await storage.read(key: 'access_token');
  }
}
