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
  _RoomEditorSolverScheduler({required super.onEmit, required super.executor});
}
