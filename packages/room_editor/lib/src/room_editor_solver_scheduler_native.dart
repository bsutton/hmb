import 'dart:async';
import 'dart:isolate';

import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler.dart';

RoomEditorSolverScheduler createRoomEditorSolverScheduler({
  required RoomEditorDragSolveCallback onEmit,
}) {
  late _RoomEditorSolverScheduler scheduler;
  // ignore: join_return_with_assignment
  scheduler = _RoomEditorSolverScheduler._(
    onEmit: onEmit,
    executor: (request) => scheduler._execute(request),
  );
  return scheduler;
}

class _RoomEditorSolverScheduler extends RoomEditorSolverScheduler {
  _RoomEditorSolverScheduler._({
    required super.onEmit,
    required super.executor,
  });

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  final _receivePort = ReceivePort();
  final _pending = <int, Completer<RoomEditorDragSolveResult>>{};
  var _nextMessageId = 0;
  StreamSubscription<dynamic>? _receiveSubscription;

  @override
  void dispose() {
    super.dispose();
    unawaited(_receiveSubscription?.cancel());
    _receivePort.close();
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Scheduler disposed'));
      }
    }
    _pending.clear();
  }

  Future<RoomEditorDragSolveResult> _execute(
    RoomEditorDragSolveRequest request,
  ) async {
    await _ensureWorker();
    final sendPort = _workerSendPort;
    if (sendPort == null) {
      return RoomEditorDragSolver.solve(request);
    }
    final completer = Completer<RoomEditorDragSolveResult>();
    final id = _nextMessageId++;
    _pending[id] = completer;
    sendPort.send((id, request));
    return completer.future;
  }

  Future<void> _ensureWorker() async {
    if (_workerSendPort != null) {
      return;
    }
    _receiveSubscription ??= _receivePort.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
        return;
      }
      final (int id, RoomEditorDragSolveResult result) =
          message as (int, RoomEditorDragSolveResult);
      final completer = _pending.remove(id);
      completer?.complete(result);
    });
    _workerIsolate = await Isolate.spawn(_workerMain, _receivePort.sendPort);
  }
}

void _workerMain(SendPort replyPort) {
  final receivePort = ReceivePort();
  replyPort.send(receivePort.sendPort);
  receivePort.listen((message) {
    final (int id, RoomEditorDragSolveRequest request) =
        message as (int, RoomEditorDragSolveRequest);
    final result = RoomEditorDragSolver.solve(request);
    replyPort.send((id, result));
  });
}
