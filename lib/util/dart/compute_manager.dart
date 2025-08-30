/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights
 Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or
     organization only.
   • Any external distribution, resale, or incorporation into
     products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

/// Signature of a compute task callback.
/// Must be a top-level or static function. Can return `FutureOr<R>`.
typedef ComputeCallback<T, R> = FutureOr<R> Function(T message);

/// Internal result envelope passed back from worker isolate.
class _IsolateResult<R> {
  final R? value;
  final Object? error;
  final String? stack;

  const _IsolateResult._success(this.value) : error = null, stack = null;

  const _IsolateResult._error(this.error, this.stack) : value = null;

  bool get isError => error != null;

  StackTrace? get stackTrace =>
      stack == null ? null : StackTrace.fromString(stack!);
}

/// Internal message to worker isolate.
class _IsolateMessage<T, R> {
  final SendPort replyTo;
  final ComputeCallback<T, R> callback;
  final T data;

  const _IsolateMessage({
    required this.replyTo,
    required this.callback,
    required this.data,
  });
}

/// Worker isolate entry point.
/// Must be a top-level or static function.
Future<void> _isolateEntry<T, R>(_IsolateMessage<T, R> msg) async {
  try {
    final result = await msg.callback(msg.data);
    msg.replyTo.send(_IsolateResult<R>._success(result));
  } catch (e, st) {
    msg.replyTo.send(_IsolateResult<R>._error(e, st.toString()));
  }
}

/// A pure-Dart equivalent of Flutter's `compute`.
/// Spawns an isolate, runs [callback] with [message], and returns the result.
///
/// [callback] must be top-level or static; [message] and the return type must
/// be sendable between isolates.
Future<R> compute<T, R>(
  ComputeCallback<T, R> callback,
  T message, {
  String? debugLabel,
}) async {
  final response = ReceivePort();
  final errors = ReceivePort();
  final exits = ReceivePort();

  final isolate = await Isolate.spawn<_IsolateMessage<T, R>>(
    _isolateEntry,
    _IsolateMessage(
      replyTo: response.sendPort,
      callback: callback,
      data: message,
    ),
    onError: errors.sendPort,
    onExit: exits.sendPort,
    debugName: debugLabel,
  );

  final completer = Completer<R>();

  StreamSubscription<dynamic>? respSub;
  StreamSubscription<dynamic>? errSub;
  StreamSubscription<dynamic>? exitSub;

  void cleanup() {
    unawaited(respSub?.cancel());
    unawaited(errSub?.cancel());
    unawaited(exitSub?.cancel());
    response.close();
    errors.close();
    exits.close();
    // Ensure isolate exits promptly if it hasn't already.
    isolate.kill(priority: Isolate.immediate);
  }

  respSub = response.listen((dynamic msg) {
    final res = msg as _IsolateResult<R>;
    if (!completer.isCompleted) {
      if (res.isError) {
        completer.completeError(res.error!, res.stackTrace ?? StackTrace.empty);
      } else {
        completer.complete(res.value as R);
      }
    }
  });

  errSub = errors.listen((dynamic msg) {
    // onError messages arrive as [error, stackTraceString]
    if (!completer.isCompleted) {
      if (msg is List && msg.length == 2) {
        final err = msg[0] as Object?;
        final st = StackTrace.fromString(msg[1]?.toString() ?? '');
        completer.completeError(err ?? 'Isolate error', st);
      } else {
        completer.completeError('Isolate error', StackTrace.empty);
      }
    }
  });

  exitSub = exits.listen((_) {
    // If the isolate exited without sending a result, ensure we fail.
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Isolate exited without a result'),
        StackTrace.empty,
      );
    }
  });

  try {
    final result = await completer.future;
    return result;
  } finally {
    cleanup();
  }
}

// ---------------------------------------------------------------------------
// Task queue + concurrency limiter (ComputeManager)
// ---------------------------------------------------------------------------

/// A class to represent a task
class ComputeTask<T, R> {
  final ComputeCallback<T, R?> function;
  final T data;
  final Completer<R?> completer;

  ComputeTask(this.function, this.data, this.completer);
}

/// Run tasks in isolates but limit the number of concurrent isolates.
class ComputeManager<T, R> {
  // ignore: strict_raw_type
  static ComputeManager? _self;

  final int maxConcurrentTasks;
  var _runningTasks = 0;
  final Queue<ComputeTask<T, R>> _taskQueue = Queue();

  factory ComputeManager({int maxConcurrentTasks = 2}) =>
      (_self ??= ComputeManager<T, R>._init(
            maxConcurrentTasks: maxConcurrentTasks,
          ))
          as ComputeManager<T, R>;

  ComputeManager._init({this.maxConcurrentTasks = 2});

  Future<R?> enqueueCompute(ComputeCallback<T, R?> function, T data) {
    final completer = Completer<R?>();
    final task = ComputeTask(function, data, completer);
    _taskQueue.add(task);
    unawaited(_maybeStartTasks());
    return completer.future;
  }

  Future<void> _maybeStartTasks() async {
    // Start as many tasks as possible until we hit maxConcurrentTasks
    while (_runningTasks < maxConcurrentTasks && _taskQueue.isNotEmpty) {
      final task = _taskQueue.removeFirst();
      _runningTasks++;
      unawaited(_runTask(task));
    }
  }

  Future<void> _runTask(ComputeTask<T, R> task) async {
    try {
      final result = await compute<T, R?>(
        task.function,
        task.data,
        debugLabel: 'ComputeTask ${task.data.runtimeType}',
      );
      task.completer.complete(result);
    } catch (e, st) {
      task.completer.completeError(e, st);
    } finally {
      _runningTasks--;
      // After a task finishes, try starting more tasks
      unawaited(_maybeStartTasks());
    }
  }
}
