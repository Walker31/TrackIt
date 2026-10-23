import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'app_mode_service.dart';
import 'sync_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final storage = const FlutterSecureStorage();

  Future<bool> login(String username, String password) async {
    try {
      final response = await _apiService.post(
        'auth/login/',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final access = response.data['access'];
        final refresh = response.data['refresh'];

        await storage.write(key: 'access_token', value: access);
        await storage.write(key: 'refresh_token', value: refresh);
        await AppModeService().setMode(AppMode.server);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String username, String password, String email) async {
    try {
      final response = await _apiService.post(
        'auth/register/',
        data: {'username': username, 'password': password, 'email': email},
      );

      if (response.statusCode == 201) {
        // Automatically login after registration
        return await login(username, password);
      }
      return false;
    } catch (e) {
      return false;
    }
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
