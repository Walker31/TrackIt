/// Runs [task] so overlapping callers share a single run instead of
/// starting their own.
///
/// A call made while a run is in progress queues one extra pass (so work
/// requested mid-run isn't lost) and completes only after that pass, so an
/// awaiting caller always sees the effect of a run that started after it
/// asked. Used by the sync service, where two concurrent runs would push and
/// pull the same rows twice.
class CoalescingRunner {
  final Future<void> Function() task;

  CoalescingRunner(this.task);

  Future<void>? _inFlight;
  bool _again = false;

  bool get isRunning => _inFlight != null;

  Future<void> run() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      _again = true;
      return inFlight;
    }
    return _inFlight = _loop().whenComplete(() => _inFlight = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await task();
    } while (_again);
  }
}
