import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/services/api_service.dart';

/// Access tokens last a day. The app used to never renew them, so users
/// were logged out daily. Now a 401 triggers one refresh and a replay, and
/// only a rejected refresh token ends the session.
void main() {
  late _FakeServer server;
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired',
      'refresh_token': 'refresh-1',
    });
    server = _FakeServer();
    ApiService.debugHttpAdapter = server;
  });

  tearDown(() => ApiService.debugHttpAdapter = null);

  /// Protected endpoints accept only the token the refresh hands out.
  void acceptOnly(String token) {
    server.protectedHandler = (auth) =>
        auth == 'Bearer $token' ? (200, {'ok': true}) : (401, {'detail': 'x'});
  }

  test('an expired access token is renewed and the request replayed', () async {
    acceptOnly('fresh');
    server.refreshHandler = () async => (200, {'access': 'fresh'});

    final response = await ApiService().get('auth/me/');

    expect(response.data, {'ok': true});
    expect(server.log, [
      'GET auth/me/ Bearer expired',
      'POST auth/token/refresh/',
      'GET auth/me/ Bearer fresh',
    ]);
    expect(await storage.read(key: 'access_token'), 'fresh');
    expect(await storage.read(key: 'refresh_token'), 'refresh-1');
  });

  test('a burst of 401s shares one refresh', () async {
    acceptOnly('fresh');
    final release = Completer<void>();
    server.refreshHandler = () async {
      await release.future;
      return (200, {'access': 'fresh'});
    };

    final api = ApiService();
    final calls = [
      api.get('transactions/'),
      api.get('fitness/workouts/'),
      ApiService().get('groups/groups/'), // a separate instance too
    ];
    await pumpEventQueue();
    release.complete();
    final responses = await Future.wait(calls);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(server.refreshCalls, 1);
  });

  test('a rejected refresh token ends the session', () async {
    acceptOnly('fresh');
    server.refreshHandler = () async => (401, {'detail': 'Token is expired'});
    final expired = expectLater(ApiService.onSessionExpired, emits(null));

    await expectLater(
      ApiService().get('auth/me/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    await expired;
    expect(await storage.read(key: 'access_token'), isNull);
    expect(await storage.read(key: 'refresh_token'), isNull);
  });

  test('an unreachable server keeps the session', () async {
    acceptOnly('fresh');
    server.refreshUnreachable = true;
    var sessionEnded = false;
    final sub = ApiService.onSessionExpired.listen((_) => sessionEnded = true);

    await expectLater(
      ApiService().get('auth/me/'),
      throwsA(isA<DioException>()),
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(sessionEnded, isFalse);
    expect(await storage.read(key: 'access_token'), 'expired');
    expect(await storage.read(key: 'refresh_token'), 'refresh-1');
  });

  test('a failed login is not treated as an expired token', () async {
    server.protectedHandler = (_) => (401, {'detail': 'No active account'});
    server.refreshHandler = () async => (200, {'access': 'fresh'});

    await expectLater(
      ApiService().post('auth/login/', data: {'username': 'a'}),
      throwsA(isA<DioException>()),
    );
    expect(server.refreshCalls, 0);
  });

  test('a replay is attempted only once', () async {
    // The server keeps refusing even the new token.
    server.protectedHandler = (_) => (401, {'detail': 'nope'});
    server.refreshHandler = () async => (200, {'access': 'fresh'});

    await expectLater(
      ApiService().get('auth/me/'),
      throwsA(isA<DioException>()),
    );
    expect(server.refreshCalls, 1);
    expect(server.log.where((l) => l.startsWith('GET')).length, 2);
  });
}

typedef _Reply = (int status, Object body);

/// Scripted backend: the refresh endpoint and everything else.
class _FakeServer implements HttpClientAdapter {
  _Reply Function(String? auth) protectedHandler = (_) => (200, {});
  Future<_Reply> Function() refreshHandler = () async => (401, {});
  bool refreshUnreachable = false;

  final log = <String>[];
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final _Reply reply;
    if (options.path.endsWith('auth/token/refresh/')) {
      refreshCalls++;
      log.add('${options.method} auth/token/refresh/');
      if (refreshUnreachable) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      reply = await refreshHandler();
    } else {
      final auth = options.headers['Authorization'] as String?;
      log.add('${options.method} ${options.path} ${auth ?? ''}'.trim());
      reply = protectedHandler(auth);
    }
    return ResponseBody.fromString(
      jsonEncode(reply.$2),
      reply.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
