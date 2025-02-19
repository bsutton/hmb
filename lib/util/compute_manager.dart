import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../ui/widgets/media/photo_gallery.dart';

// A class to represent a task
class ComputeTask {
  ComputeTask(this.function, this.data, this.completer);
  final ComputeCallback<ThumbnailPaths, String?> function;
  final ThumbnailPaths data;
  final Completer<String?> completer;
}

/// Run a task in an isolate but limit the number of concurrent isolates.
class ComputeManager {
  factory ComputeManager({int maxConcurrentTasks = 2}) =>
      _self ??= ComputeManager._init(maxConcurrentTasks: maxConcurrentTasks);

  ComputeManager._init({this.maxConcurrentTasks = 2});

  static ComputeManager? _self;

  final int maxConcurrentTasks;
  int _runningTasks = 0;
  final Queue<ComputeTask> _taskQueue = Queue();

  Future<String?> enqueueCompute(
    ComputeCallback<ThumbnailPaths, String?> function,
    ThumbnailPaths message,
  ) async {
    final completer = Completer<String?>();
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

  Future<void> _runTask(ComputeTask task) async {
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
