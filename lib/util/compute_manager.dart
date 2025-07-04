/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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
class ComputeManager<T, R> {
  factory ComputeManager({int maxConcurrentTasks = 2}) =>
      (_self ??= ComputeManager<T, R>._init(
            maxConcurrentTasks: maxConcurrentTasks,
          ))
          as ComputeManager<T, R>;

  ComputeManager._init({this.maxConcurrentTasks = 2});

  // ignore: strict_raw_type
  static ComputeManager? _self;

  final int maxConcurrentTasks;
  var _runningTasks = 0;
  final Queue<ComputeTask<T, R>> _taskQueue = Queue();

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
      final result = await compute(
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
