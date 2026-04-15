import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'room_canvas_models.dart';
import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler.dart';

RoomEditorSolverScheduler createRoomEditorSolverScheduler({
  required RoomEditorDragSolveCallback onEmit,
}) => _RoomEditorSolverScheduler(onEmit: onEmit);

class _RoomEditorSolverScheduler implements RoomEditorSolverScheduler {
  final RoomEditorDragSolveCallback onEmit;

  _RoomEditorSolverScheduler({required this.onEmit});

  RoomEditorDragSolveRequest? _activeRequest;
  RoomEditorDragSolveRequest? _queuedRequest;
  RoomEditorIntPoint? _latestPointerTarget;
  var _epoch = 0;
  var _disposed = false;

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  final _receivePort = ReceivePort();
  final _pending = <int, Completer<RoomEditorDragSolveResult>>{};
  var _nextMessageId = 0;

  @override
  void schedule(RoomEditorDragSolveRequest request) {
    if (_disposed) {
      return;
    }
    _latestPointerTarget = request.movedTarget;
    if (_activeRequest == null) {
      _start(request, _epoch);
      return;
    }
    _queuedRequest = request;
  }

  @override
  void cancel() {
    _epoch++;
    _activeRequest = null;
    _queuedRequest = null;
    _latestPointerTarget = null;
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    _receivePort.close();
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
  }

  void _start(RoomEditorDragSolveRequest request, int epoch) {
    _activeRequest = request;
    unawaited(_run(request, epoch));
  }

  Future<void> _run(RoomEditorDragSolveRequest request, int epoch) async {
    final result = await _execute(request);
    if (_disposed || epoch != _epoch) {
      return;
    }
    if (_isRelevant(result)) {
      onEmit(result);
    }
    if (_activeRequest == request) {
      _activeRequest = null;
    }
    final next = _queuedRequest;
    _queuedRequest = null;
    if (next != null) {
      _start(next, epoch);
    }
  }

  bool _isRelevant(RoomEditorDragSolveResult result) {
    if (result.solvedDocument == null) {
      return false;
    }
    final latest = _latestPointerTarget;
    if (latest == null) {
      return false;
    }
    final dx = result.request.movedTarget.x - latest.x;
    final dy = result.request.movedTarget.y - latest.y;
    return sqrt(dx * dx + dy * dy) <= result.request.emitDistanceThreshold;
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
    _receivePort.listen((message) {
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
