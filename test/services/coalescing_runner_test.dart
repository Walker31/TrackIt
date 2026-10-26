import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/services/coalescing_runner.dart';

/// Overlapping syncs used to run concurrently, pushing and pulling the same
/// rows twice (duplicate expenses, 500s on the server's client_id
/// constraint). The sync service now funnels every call through this runner.
void main() {
  test('a single call runs the task once', () async {
    var runs = 0;
    final runner = CoalescingRunner(() async => runs++);
    await runner.run();
    expect(runs, 1);
    expect(runner.isRunning, isFalse);
  });

  test(
    'overlapping calls share the run and queue exactly one more pass',
    () async {
      var runs = 0;
      final gates = [Completer<void>(), Completer<void>()];
      final runner = CoalescingRunner(() async {
        final gate = gates[runs++];
        await gate.future;
      });

      final first = runner.run();
      // Three more callers arrive while the first pass is blocked.
      final others = [runner.run(), runner.run(), runner.run()];
      expect(runs, 1, reason: 'no second concurrent run');

      gates[0].complete();
      await pumpEventQueue();
      expect(runs, 2, reason: 'mid-run calls collapse into one extra pass');

      gates[1].complete();
      await Future.wait([first, ...others]);
      expect(runs, 2);
      expect(runner.isRunning, isFalse);
    },
  );

  test(
    'a caller that joins mid-run waits for the pass after it asked',
    () async {
      final log = <String>[];
      var pass = 0;
      final gate = Completer<void>();
      final runner = CoalescingRunner(() async {
        final n = ++pass;
        log.add('start $n');
        if (n == 1) await gate.future;
        log.add('end $n');
      });

      final first = runner.run();
      final joined = runner.run().then((_) => log.add('joined done'));
      gate.complete();
      await Future.wait([first, joined]);

      // The joining caller only completes after pass 2, which started after
      // it asked, so it sees fresh data rather than a run already underway.
      expect(log, ['start 1', 'end 1', 'start 2', 'end 2', 'joined done']);
    },
  );

  test('sequential calls each get their own run', () async {
    var runs = 0;
    final runner = CoalescingRunner(() async => runs++);
    await runner.run();
    await runner.run();
    expect(runs, 2);
  });

  test('a failing run releases the lock for the next call', () async {
    var runs = 0;
    final runner = CoalescingRunner(() async {
      runs++;
      if (runs == 1) throw StateError('network down');
    });

    await expectLater(runner.run(), throwsStateError);
    expect(runner.isRunning, isFalse);
    await runner.run();
    expect(runs, 2);
  });
}
