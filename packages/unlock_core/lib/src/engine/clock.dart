import 'dart:async';

abstract interface class Clock {
  DateTime now();

  /// Completes after [duration], or as soon as [abort] completes.
  Future<void> sleep(Duration duration, {Future<void>? abort});
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> sleep(Duration duration, {Future<void>? abort}) {
    final done = Completer<void>();
    final timer = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    abort?.whenComplete(() {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    }).ignore();
    return done.future;
  }
}

/// Thrown out of a host's flow when it is cancelled.
final class RunCancelled implements Exception {
  const RunCancelled();
}

/// Thrown by [RunControl.guard] when the timeout elapses first.
final class RunTimeout implements Exception {
  const RunTimeout();
}

/// Cancellation and clock-based timeouts for one host's run.
final class RunControl {
  RunControl(this.clock);

  final Clock clock;
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const RunCancelled();
  }

  Future<void> sleep(Duration duration) async {
    throwIfCancelled();
    if (duration > Duration.zero) {
      await clock.sleep(duration, abort: whenCancelled);
    }
    throwIfCancelled();
  }

  /// Waits for [future]; throws [RunCancelled] or [RunTimeout] if those come first.
  Future<T> guard<T>(Future<T> future, {Duration? timeout}) async {
    throwIfCancelled();
    final settled = Completer<void>();
    future.then((_) {}, onError: (Object _) {}).whenComplete(() {
      if (!settled.isCompleted) settled.complete();
    }).ignore();
    final stop = Future.any([settled.future, whenCancelled]);
    final outcome = await Future.any<Object?>([
      future.then<Object?>(_Value.new),
      whenCancelled.then<Object?>((_) => const RunCancelled()),
      if (timeout != null)
        clock
            .sleep(timeout, abort: stop)
            .then<Object?>((_) => const RunTimeout()),
    ]);
    if (outcome is _Value) return outcome.value as T;
    if (isCancelled) throw const RunCancelled();
    if (outcome is RunTimeout && !settled.isCompleted) throw outcome;
    return future;
  }
}

final class _Value {
  const _Value(this.value);

  final Object? value;
}
