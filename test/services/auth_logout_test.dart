import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/services/api_service.dart';
import 'package:trackit/services/auth_service.dart';
import 'package:trackit/services/database_service.dart';

/// Logging out revokes the refresh token on the server, but never waits on
/// it: offline or with a slow server, the device is still signed out.
/// Rate-limited login and sign-up say so instead of quoting a status code.
void main() {
  late _FakeServer server;
  const storage = FlutterSecureStorage();

  setUp(() async {
    // Logout also resets the sync cursors kept in the database.
    await DatabaseService.openInMemoryForTesting();
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
    });
    server = _FakeServer();
    ApiService.debugHttpAdapter = server;
  });

  tearDown(() => ApiService.debugHttpAdapter = null);

  group('logout', () {
    test('sends the refresh token to the server, then clears it', () async {
      server.handler = (_) async => (204, null, null);

      await AuthService().logout();

      expect(server.log, ['POST auth/logout/ {"refresh":"refresh-1"}']);
      expect(await storage.read(key: 'access_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
    });

    test('offline still signs out', () async {
      server.handler = (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );

      await AuthService().logout();

      expect(await storage.read(key: 'refresh_token'), isNull);
    });

    test('a server that never answers does not hold up signing out', () async {
      server.handler = (_) => Completer<_Reply>().future;

      final watch = Stopwatch()..start();
      await AuthService().logout();

      expect(watch.elapsed, lessThan(AuthService.logoutTimeout * 2));
      expect(await storage.read(key: 'refresh_token'), isNull);
    });

    test(
      'an error answer (old server without the endpoint) is ignored',
      () async {
        server.handler = (_) async => (404, {'detail': 'Not found.'}, null);

        await AuthService().logout();

        expect(server.refreshCalls, 0);
        expect(await storage.read(key: 'refresh_token'), isNull);
      },
    );

    test('nothing is sent without a refresh token', () async {
      FlutterSecureStorage.setMockInitialValues({});

      await AuthService().logout();

      expect(server.log, isEmpty);
    });
  });

  group('rate limits', () {
    test('login: 429 says to wait, using Retry-After', () async {
      server.handler = (_) async => (429, {'detail': 'throttled'}, '42');

      final error = await AuthService().login('alice', 'pw');

      expect(error, 'Too many attempts. Try again in 42 seconds.');
    });

    test('register: 429 says to wait', () async {
      server.handler = (_) async => (429, {'detail': 'throttled'}, '3000');

      final error = await AuthService().register('alice', 'pw', '');

      expect(error, 'Too many attempts. Try again in 50 minutes.');
    });

    test('wait wording', () {
      String msg(String? retryAfter) => AuthService.tooManyAttempts(
        Headers.fromMap({
          if (retryAfter != null) 'retry-after': [retryAfter],
        }),
      );
      expect(msg(null), 'Too many attempts. Try again in a minute.');
      expect(msg('junk'), 'Too many attempts. Try again in a minute.');
      expect(msg('1'), 'Too many attempts. Try again in 1 second.');
      expect(msg('59'), 'Too many attempts. Try again in 59 seconds.');
      expect(msg('60'), 'Too many attempts. Try again in a minute.');
      expect(msg('125'), 'Too many attempts. Try again in 3 minutes.');
      expect(msg('3600'), 'Too many attempts. Try again in an hour.');
      expect(msg('7300'), 'Too many attempts. Try again in 3 hours.');
    });
  });
}

typedef _Reply = (int status, Object? body, String? retryAfter);

class _FakeServer implements HttpClientAdapter {
  Future<_Reply> Function(RequestOptions options) handler = (_) async =>
      (200, {}, null);

  final log = <String>[];
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('auth/token/refresh')) {
      refreshCalls++;
      return ResponseBody.fromString('{}', 401);
    }
    final body = options.data == null ? '' : ' ${jsonEncode(options.data)}';
    log.add('${options.method} ${options.path}$body');
    final reply = await handler(options);
    return ResponseBody.fromString(
      reply.$2 == null ? '' : jsonEncode(reply.$2),
      reply.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (reply.$3 != null) 'retry-after': [reply.$3!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
