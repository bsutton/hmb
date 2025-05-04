import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

// A class to represent a task
class ComputeTask<T, R> {
  ComputeTask(this.function, this.data, this.completer);
  final ComputeCallback<T, R?> function;
  final T data;
  final Completer<R?> completer;
}

/// Run a task in an isolate but limit the number of concurrent isolates.
class ComputeManager {
  factory ComputeManager({int maxConcurrentTasks = 2}) =>
      _self ??= ComputeManager._init(maxConcurrentTasks: maxConcurrentTasks);

  ComputeManager._init({this.maxConcurrentTasks = 2});

  static ComputeManager? _self;

  final int maxConcurrentTasks;
  var _runningTasks = 0;
  final Queue<ComputeTask<dynamic, dynamic>> _taskQueue = Queue();

  Future<R?> enqueueCompute<T, R>(ComputeCallback<T, R?> function, T message) {
    final completer = Completer<R?>();
    final task = ComputeTask(function, message, completer);
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

  Future<void> _runTask(ComputeTask<dynamic, dynamic> task) async {
    try {
      final result = await compute(
        task.function,
        task.data,
        debugLabel: 'ComputeTask',
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
