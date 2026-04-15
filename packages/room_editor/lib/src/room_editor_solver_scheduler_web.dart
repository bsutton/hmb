import 'dart:async';

import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler.dart';

RoomEditorSolverScheduler createRoomEditorSolverScheduler({
  required RoomEditorDragSolveCallback onEmit,
}) => _RoomEditorSolverScheduler(
  onEmit: onEmit,
  executor: (request) => Future<RoomEditorDragSolveResult>.microtask(
    () => RoomEditorDragSolver.solve(request),
  ),
);

class _RoomEditorSolverScheduler extends RoomEditorSolverScheduler {
  // final RoomEditorDragSolveCallback onEmit;
  // final Future<RoomEditorDragSolveResult>
  // Function(RoomEditorDragSolveRequest)
  // executor;

  _RoomEditorSolverScheduler({required super.onEmit, required super.executor});

  // RoomEditorDragSolveRequest? _activeRequest;
  // RoomEditorDragSolveRequest? _queuedRequest;
  // RoomEditorIntPoint? _latestPointerTarget;
  // var _epoch = 0;
  // var _disposed = false;

  // @override
  // void schedule(RoomEditorDragSolveRequest request) {
  //   if (_disposed) {
  //     return;
  //   }
  //   _latestPointerTarget = request.movedTarget;
  //   if (_activeRequest == null) {
  //     _start(request, _epoch);
  //     return;
  //   }
  //   _queuedRequest = request;
  // }

  // @override
  // void cancel() {
  //   _epoch++;
  //   _activeRequest = null;
  //   _queuedRequest = null;
  //   _latestPointerTarget = null;
  // }

  // @override
  // void dispose() {
  //   cancel();
  //   _disposed = true;
  // }

  // void _start(RoomEditorDragSolveRequest request, int epoch) {
  //   _activeRequest = request;
  //   unawaited(_run(request, epoch));
  // }

  // Future<void> _run(RoomEditorDragSolveRequest request, int epoch) async {
  //   final result = await executor(request);
  //   if (_disposed || epoch != _epoch) {
  //     return;
  //   }
  //   if (_isRelevant(result)) {
  //     onEmit(result);
  //   }
  //   if (_activeRequest == request) {
  //     _activeRequest = null;
  //   }
  //   final next = _queuedRequest;
  //   _queuedRequest = null;
  //   if (next != null) {
  //     _start(next, epoch);
  //   }
  // }

  // bool _isRelevant(RoomEditorDragSolveResult result) {
  //   if (result.solvedDocument == null) {
  //     return false;
  //   }
  //   final latest = _latestPointerTarget;
  //   if (latest == null) {
  //     return false;
  //   }
  //   final dx = result.request.movedTarget.x - latest.x;
  //   final dy = result.request.movedTarget.y - latest.y;
  //   return sqrt(dx * dx + dy * dy) <= result.request.emitDistanceThreshold;
  // }
}
