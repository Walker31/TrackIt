import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/services/sync_service.dart';
import 'package:trackit/services/sync_triggers.dart';

/// Changes made offline used to sit until the next edit; the triggers sync
/// on reconnect, on resume, and retry while the server is unreachable.
void main() {
  late StreamController<List<ConnectivityResult>> connectivity;
  late StreamController<SyncOutcome> outcomes;
  late List<bool> syncs; // forcePull of each sync started
  late int pending;
  late SyncTriggers triggers;

  void setUpTriggers() {
    connectivity = StreamController();
    outcomes = StreamController();
    syncs = [];
    pending = 0;
    triggers = SyncTriggers(
      connectivity: connectivity.stream,
      outcomes: outcomes.stream,
      sync: ({bool forcePull = false}) async => syncs.add(forcePull),
      pendingChanges: () async => pending,
      retryDelays: const [Duration(seconds: 30), Duration(minutes: 1)],
    )..start();
  }

  void tearDownTriggers() {
    triggers.dispose();
    connectivity.close();
    outcomes.close();
  }

  const wifi = [ConnectivityResult.wifi];
  const none = [ConnectivityResult.none];

  testWidgets('coming back online syncs with a fresh pull', (tester) async {
    setUpTriggers();
    connectivity.add(none);
    await tester.pump();
    expect(syncs, isEmpty);

    connectivity.add(wifi);
    await tester.pump();
    expect(syncs, [true]);
    tearDownTriggers();
  });

  testWidgets('the first connectivity event alone does not sync', (
    tester,
  ) async {
    setUpTriggers();
    connectivity.add(wifi);
    connectivity.add([ConnectivityResult.mobile]);
    await tester.pump();
    expect(syncs, isEmpty);
    tearDownTriggers();
  });

  testWidgets('returning to the app syncs without forcing a pull', (
    tester,
  ) async {
    setUpTriggers();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(syncs, [false]);
    tearDownTriggers();
  });

  testWidgets('an unreachable server with waiting changes retries, backing '
      'off', (tester) async {
    setUpTriggers();
    pending = 2;

    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    expect(triggers.isRetryScheduled, isTrue);
    await tester.pump(const Duration(seconds: 29));
    expect(syncs, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(syncs, [false]);

    // Second failure waits the next delay, then the last one repeats.
    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    await tester.pump(const Duration(seconds: 59));
    expect(syncs, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(syncs, hasLength(2));

    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(syncs, hasLength(3));
    tearDownTriggers();
  });

  testWidgets('nothing waiting means no retry', (tester) async {
    setUpTriggers();
    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    expect(triggers.isRetryScheduled, isFalse);
    tearDownTriggers();
  });

  testWidgets('reaching the server cancels the retry and resets the backoff', (
    tester,
  ) async {
    setUpTriggers();
    pending = 1;
    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();

    outcomes.add(SyncOutcome.reached);
    await tester.pump();
    expect(triggers.isRetryScheduled, isFalse);

    // Back to the first delay.
    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(syncs, hasLength(2));
    tearDownTriggers();
  });

  testWidgets('going offline drops the retry; reconnecting syncs instead', (
    tester,
  ) async {
    setUpTriggers();
    pending = 1;
    connectivity.add(wifi);
    outcomes.add(SyncOutcome.unreachable);
    await tester.pump();
    expect(triggers.isRetryScheduled, isTrue);

    connectivity.add(none);
    await tester.pump();
    expect(triggers.isRetryScheduled, isFalse);
    await tester.pump(const Duration(minutes: 5));
    expect(syncs, isEmpty);

    connectivity.add(wifi);
    await tester.pump();
    expect(syncs, [true]);
    tearDownTriggers();
  });
}
