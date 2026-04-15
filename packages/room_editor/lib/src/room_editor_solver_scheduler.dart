import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler_native.dart'
    if (dart.library.js_interop) 'room_editor_solver_scheduler_web.dart'
    as impl;

typedef RoomEditorDragSolveCallback =
    void Function(RoomEditorDragSolveResult result);

abstract class RoomEditorSolverScheduler {
  void schedule(RoomEditorDragSolveRequest request);
  void cancel();
  void dispose();
}

RoomEditorSolverScheduler createRoomEditorSolverScheduler({
  required RoomEditorDragSolveCallback onEmit,
}) => impl.createRoomEditorSolverScheduler(onEmit: onEmit);
