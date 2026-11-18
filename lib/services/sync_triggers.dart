import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'sync_service.dart';

/// Starts syncs nobody asked for, so changes made offline don't wait for the
/// next edit to upload:
///
/// - when the device gets a connection back (with a fresh pull),
/// - when the app comes back to the foreground,
/// - when a sync couldn't reach the server and changes are still waiting,
///   retrying after [retryDelays] (the last one repeats).
///
/// [SyncService.performSync] already skips local mode and merges overlapping
/// calls, so the triggers don't need to.
class SyncTriggers with WidgetsBindingObserver {
  SyncTriggers({
    required Stream<List<ConnectivityResult>> connectivity,
    required Stream<SyncOutcome> outcomes,
    required this.sync,
    required this.pendingChanges,
    this.retryDelays = defaultRetryDelays,
  }) : _connectivity = connectivity,
       _outcomes = outcomes;

  /// Wired to the real connectivity plugin and [SyncService].
  factory SyncTriggers.forApp() => SyncTriggers(
    connectivity: Connectivity().onConnectivityChanged,
    outcomes: SyncService().onSyncOutcome,
    sync: ({bool forcePull = false}) =>
        SyncService().performSync(forcePull: forcePull),
    pendingChanges: SyncService.pendingChanges,
  );

  static const defaultRetryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  final Stream<List<ConnectivityResult>> _connectivity;
  final Stream<SyncOutcome> _outcomes;
  final Future<void> Function({bool forcePull}) sync;
  final Future<int> Function() pendingChanges;
  final List<Duration> retryDelays;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<SyncOutcome>? _outcomeSub;
  Timer? _retry;
  int _failedPasses = 0;

  /// Null until the first connectivity event: the startup sync already
  /// covers the state the app opened in.
  bool? _offline;

  bool get isRetryScheduled => _retry?.isActive ?? false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.listen(_onConnectivity);
    _outcomeSub = _outcomes.listen(_onOutcome);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _outcomeSub?.cancel();
    _cancelRetry();
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    final wasOffline = _offline;
    _offline = offline;
    if (offline) {
      // Nothing to retry against; the reconnect below takes over.
      _cancelRetry();
      _failedPasses = 0;
    } else if (wasOffline == true) {
      _syncNow(forcePull: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Not forced: performSync pulls anyway if the last pull is stale.
    if (state == AppLifecycleState.resumed) _syncNow();
  }

  Future<void> _onOutcome(SyncOutcome outcome) async {
    if (outcome == SyncOutcome.reached) {
      _cancelRetry();
      _failedPasses = 0;
      return;
    }
    if (isRetryScheduled || _offline == true) return;
    if (await pendingChanges() == 0) return;
    // The pending check is async; another trigger may have landed meanwhile.
    if (isRetryScheduled || _offline == true) return;
    final delay = retryDelays[_failedPasses.clamp(0, retryDelays.length - 1)];
    _failedPasses++;
    debugPrint('Server unreachable; retrying sync in ${delay.inSeconds}s');
    _retry = Timer(delay, () {
      _retry = null;
      _syncNow();
    });
  }

  void _syncNow({bool forcePull = false}) {
    _cancelRetry();
    unawaited(sync(forcePull: forcePull));
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }
}
