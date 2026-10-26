import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/services/api_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/sync_outbox.dart';

/// Queued deletes used to retry forever when the server kept refusing one.
void main() {
  late Database db;
  late _StatusServer server;

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
    FlutterSecureStorage.setMockInitialValues({'access_token': 't'});
    server = _StatusServer();
    ApiService.debugHttpAdapter = server;
  });

  tearDown(() => ApiService.debugHttpAdapter = null);

  Future<List<Map<String, Object?>>> queued() => db.query(SyncOutbox.table);

  test('a request the server keeps refusing is eventually dropped', () async {
    server.status = 403;
    await SyncOutbox.enqueueDelete(db, 'transactions/1/');

    for (var i = 1; i < SyncOutbox.maxAttempts; i++) {
      await SyncOutbox.drain(ApiService());
      expect((await queued()).single['attempts'], i);
    }
    await SyncOutbox.drain(ApiService());
    expect(await queued(), isEmpty);
  });

  test('being offline keeps the request without counting a try', () async {
    server.offline = true;
    await SyncOutbox.enqueueDelete(db, 'transactions/1/');

    for (var i = 0; i < SyncOutbox.maxAttempts + 1; i++) {
      await SyncOutbox.drain(ApiService());
    }
    expect((await queued()).single['attempts'], 0);
  });

  test('accepted and already-gone requests are removed', () async {
    await SyncOutbox.enqueueDelete(db, 'transactions/1/');
    server.status = 204;
    await SyncOutbox.drain(ApiService());
    expect(await queued(), isEmpty);

    await SyncOutbox.enqueueDelete(db, 'transactions/2/');
    server.status = 404;
    await SyncOutbox.drain(ApiService());
    expect(await queued(), isEmpty);
  });
}

class _StatusServer implements HttpClientAdapter {
  int status = 200;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
