import 'dart:async';

/// FIFO async lock:
/// - Ensures only one scheduler action executes at a time in this isolate.
/// - Subsequent calls are queued (not dropped/coalesced).
class SchedulerRunLock {
  Future<void> _tail = Future.value();
  bool _running = false;

  bool get isRunning => _running;

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _tail = _tail.then((_) async {
      _running = true;
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _running = false;
      }
    });

    // Keep the queue alive even if the previous action errored.
    _tail = _tail.catchError((_) {});

    return completer.future;
  }
}
