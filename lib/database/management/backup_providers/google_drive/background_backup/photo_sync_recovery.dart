import 'dart:async';

/// Owns one worker at a time, including its asynchronous shutdown and startup.
/// The worker reloads the durable queue on every attempt.
class PhotoSyncRecovery {
  PhotoSyncRecovery({
    required this.run,
    required this.stop,
    required this.isRecoverable,
    required this.onChanged,
    required this.onError,
    this.retryDelay = const Duration(seconds: 3),
    this.maxRetryDelay = const Duration(minutes: 1),
  });

  final Future<void> Function(bool Function() interrupted) run;
  final void Function() stop;
  final bool Function(Object error) isRecoverable;
  final void Function() onChanged;
  final void Function(Object error) onError;
  final Duration retryDelay;
  final Duration maxRetryDelay;
  Future<void>? _flight;
  Timer? _retry;
  var _generation = 0;
  var _attempt = 0;
  var _foreground = true;
  var _cancelled = false;
  var _requested = false;
  var _active = false;
  Object? lastError;

  bool get isRunning => _active;
  bool get isCancelled => _cancelled;
  bool get isWaiting => _requested && !_active;

  Future<void> start({bool automatic = false}) async {
    if (automatic && (_cancelled || !_foreground)) {
      return;
    }
    if (!automatic) {
      _cancelled = false;
      _attempt = 0;
    }
    _requested = true;
    _retry?.cancel();
    if (_active) {
      return;
    }
    // A killed isolate must exit and its database acknowledgements must drain
    // before a replacement is allowed to read the pending queue.
    final previous = _flight;
    if (previous != null) {
      await previous;
    }
    if (_active || _cancelled || !_foreground || !_requested) {
      return;
    }
    final generation = ++_generation;
    _active = true;
    lastError = null;
    onChanged();
    final flight = _run(generation);
    _flight = flight;
    await flight;
    if (identical(_flight, flight)) {
      _flight = null;
    }
  }

  Future<void> _run(int generation) async {
    try {
      await run(() => generation != _generation);
      if (generation == _generation) {
        _requested = false;
        _attempt = 0;
      }
    } on Object catch (error) {
      if (generation == _generation) {
        lastError = error;
        onError(error);
        if (isRecoverable(error)) {
          // Poll the pending work while foregrounded. This also recovers when
          // connectivity returns without requiring a platform plugin or tap.
          final multiplier = 1 << (_attempt < 5 ? _attempt : 5);
          final delay = retryDelay * multiplier;
          _attempt++;
          _retry = Timer(
            delay > maxRetryDelay ? maxRetryDelay : delay,
            () => unawaited(start(automatic: true)),
          );
        } else {
          _requested = false;
        }
      }
    } finally {
      _active = false;
      onChanged();
    }
  }

  void cancel() {
    _cancelled = true;
    _requested = false;
    lastError = null;
    _interrupt();
  }

  void pause() {
    _foreground = false;
    _interrupt();
  }

  Future<void> resume() async {
    _foreground = true;
    await start(automatic: true);
  }

  void _interrupt() {
    _generation++;
    _retry?.cancel();
    _active = false;
    stop();
    onChanged();
  }
}
