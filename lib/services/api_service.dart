import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  late Dio dio;
  final storage = const FlutterSecureStorage();

  static const String defaultBaseUrl = 'https://track.adityajanga.in/api/';

  /// Backend root; changed at runtime when the user points the app at their
  /// own server. Applied per request so existing instances pick it up.
  static String baseUrl = defaultBaseUrl;

  /// Trim, and make sure a non-empty URL ends with a single `/`.
  static String normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  /// PaisaPulse blueprint endpoints (see Notion "Expense Tracker Blueprint").
  static const String transactionsPath = 'transactions/';
  static const String categoriesPath = 'categories/';
  static const String eventsPath = 'events/';
  static const String analyticsPath = 'analytics/';

  /// Tests: route every request (including token refreshes) through a fake.
  @visibleForTesting
  static HttpClientAdapter? debugHttpAdapter;

  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );
    if (debugHttpAdapter != null) dio.httpClientAdapter = debugHttpAdapter!;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = baseUrl;
          final token = await storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final request = e.requestOptions;
          // An expired access token (1-day lifetime) gets a 401: renew it
          // with the refresh token and replay the request once.
          if (e.response?.statusCode != 401 ||
              request.extra[_retriedKey] == true ||
              _isAuthPath(request.path)) {
            return handler.next(e);
          }
          final outcome = await _refreshAccessToken();
          if (outcome != _RefreshOutcome.refreshed) {
            return handler.next(e);
          }
          request.extra[_retriedKey] = true;
          try {
            // onRequest re-reads the token, so the replay uses the new one.
            return handler.resolve(await dio.fetch(request));
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  static const _retriedKey = 'auth_retried';
  static const _refreshPath = 'auth/token/refresh/';

  /// Login/register/refresh failures are real answers, not expired tokens.
  static bool _isAuthPath(String path) =>
      path.contains('auth/login') ||
      path.contains('auth/register') ||
      path.contains('auth/token');

  /// Fires when the refresh token itself is rejected (expired or revoked):
  /// the session is over and the user has to log in again.
  static Stream<void> get onSessionExpired => _sessionExpired.stream;
  static final _sessionExpired = StreamController<void>.broadcast();

  // Shared across instances so a burst of 401s triggers a single refresh.
  static Future<_RefreshOutcome>? _refreshing;

  static Future<_RefreshOutcome> _refreshAccessToken() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  static Future<_RefreshOutcome> _doRefresh() async {
    const storage = FlutterSecureStorage();
    final refresh = await storage.read(key: 'refresh_token');
    if (refresh == null) return _RefreshOutcome.rejected;

    // A bare client: the refresh call must not go through the interceptor.
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );
    if (debugHttpAdapter != null) client.httpClientAdapter = debugHttpAdapter!;
    try {
      final response = await client.post(
        _refreshPath,
        data: {'refresh': refresh},
      );
      final access = response.data['access'];
      if (access is! String) return _RefreshOutcome.unavailable;
      await storage.write(key: 'access_token', value: access);
      // Ready for refresh-token rotation if the server enables it.
      final rotated = response.data['refresh'];
      if (rotated is String) {
        await storage.write(key: 'refresh_token', value: rotated);
      }
      return _RefreshOutcome.refreshed;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        // The server refused the refresh token: end the session.
        await storage.delete(key: 'access_token');
        await storage.delete(key: 'refresh_token');
        _sessionExpired.add(null);
        return _RefreshOutcome.rejected;
      }
      // Offline / server down: keep the session and try again later.
      return _RefreshOutcome.unavailable;
    } finally {
      client.close();
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await dio.put(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  /// Issue a request with an arbitrary verb (used to replay queued writes).
  Future<Response> send(String method, String path, {dynamic data}) {
    return dio.request(
      path,
      data: data,
      options: Options(method: method),
    );
  }

  Future<Response> delete(String path) async {
    try {
      return await dio.delete(path);
    } catch (e) {
      rethrow;
    }
  }
}

enum _RefreshOutcome {
  /// A new access token is stored.
  refreshed,

  /// The server rejected the refresh token; the session is over.
  rejected,

  /// Couldn't reach the server; keep the session and retry later.
  unavailable,
}
