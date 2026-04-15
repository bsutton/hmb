import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../room_editor.dart';
import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler_native.dart'
    if (dart.library.js_interop) 'room_editor_solver_scheduler_web.dart'
    as impl;

typedef RoomEditorDragSolveCallback =
    void Function(RoomEditorDragSolveResult result);

abstract class RoomEditorSolverScheduler {
  final RoomEditorDragSolveCallback onEmit;
  final Future<RoomEditorDragSolveResult> Function(RoomEditorDragSolveRequest)
  executor;

  RoomEditorDragSolveRequest? _activeRequest;
  RoomEditorDragSolveRequest? _queuedRequest;
  RoomEditorIntPoint? _latestPointerTarget;
  String? _activeRequestKey;
  String? _queuedRequestKey;
  String? _lastCompletedRequestKey;
  var _epoch = 0;
  var _disposed = false;

  RoomEditorSolverScheduler({required this.onEmit, required this.executor});

  void cancel() {
    final active = _activeRequest;
    final queued = _queuedRequest;
    _epoch++;
    _activeRequest = null;
    _queuedRequest = null;
    _activeRequestKey = null;
    _queuedRequestKey = null;
    _latestPointerTarget = null;
    if (active != null || queued != null) {
      debugPrint(
        '[room_drag] cancel epoch=$_epoch'
        ' active=${active == null ? "<none>" : _traceLabel(active)}'
        ' queued=${queued == null ? "<none>" : _traceLabel(queued)}',
      );
    }
  }

  void schedule(RoomEditorDragSolveRequest request) {
    if (_disposed) {
      return;
    }
    final requestKey = _requestKey(request);
    _latestPointerTarget = request.movedTarget;
    if (_activeRequestKey == requestKey) {
      debugPrint(
        'Dropping duplicate active solve request'
        ' ${_traceLabel(request)}',
      );
      return;
    }
    if (_queuedRequestKey == requestKey) {
      debugPrint(
        'Dropping duplicate queued solve request'
        ' ${_traceLabel(request)}',
      );
      return;
    }
    if (_activeRequest == null) {
      if (_lastCompletedRequestKey == requestKey) {
        debugPrint(
          'Dropping duplicate completed solve request'
          ' ${_traceLabel(request)}',
        );
        return;
      }
      debugPrint(
        'Scheduling new solve request ${_traceLabel(request)}'
        ' queueLag=${_latencyMs(request)}ms',
      );
      _start(request, _epoch, requestKey);
      return;
    }
    if (_queuedRequest != null) {
      debugPrint(
        'Replacing queued solve request'
        ' ${_traceLabel(_queuedRequest!)}'
        ' with ${_traceLabel(request)}',
      );
    } else {
      debugPrint(
        'Queuing new solve request ${_traceLabel(request)}'
        ' queueLag=${_latencyMs(request)}ms',
      );
    }
    _queuedRequest = request;
    _queuedRequestKey = requestKey;
  }

  void _start(
    RoomEditorDragSolveRequest request,
    int epoch,
    String requestKey,
  ) {
    _activeRequest = request;
    _activeRequestKey = requestKey;
    unawaited(_run(request, epoch));
  }

  void dispose() {
    cancel();
    _disposed = true;
  }

  Future<void> _run(RoomEditorDragSolveRequest request, int epoch) async {
    final stopWatch = Stopwatch()..start();
    debugPrint('*' * 80);
    debugPrint(
      'Running solve request ${_traceLabel(request)}'
      ' startLag=${_latencyMs(request)}ms',
    );
    debugPrint('*' * 80);

    final result = await executor(request);
    if (_disposed || epoch != _epoch) {
      stopWatch.stop();
      debugPrint(
        '[room_drag] discarding stale solve result'
        ' ${_traceLabel(request)}'
        ' solveDuration=${stopWatch.elapsedMilliseconds}ms'
        ' totalLag=${_latencyMs(request)}ms'
        ' epoch=$epoch currentEpoch=$_epoch disposed=$_disposed',
      );
      return;
    }
    if (_isRelevant(result)) {
      onEmit(result);
    }
    if (_activeRequest == request) {
      _activeRequest = null;
      _lastCompletedRequestKey = _activeRequestKey;
      _activeRequestKey = null;
    }

    stopWatch.stop();
    debugPrint('*' * 80);
    debugPrint(
      'Completed solve ${_traceLabel(request)}'
      ' solveDuration=${stopWatch.elapsedMilliseconds}ms'
      ' totalLag=${_latencyMs(request)}ms',
    );
    debugPrint('*' * 80);

    final next = _queuedRequest;
    final nextKey = _queuedRequestKey;
    _queuedRequest = null;
    _queuedRequestKey = null;
    if (next != null) {
      _start(next, epoch, nextKey ?? _requestKey(next));
    }
  }

  String _requestKey(RoomEditorDragSolveRequest request) => [
    request.movedIndex,
    request.movedTarget.x,
    request.movedTarget.y,
    _documentKey(request.currentDocument),
    if (request.gestureBaseDocument == null)
      '<none>'
    else
      _documentKey(request.gestureBaseDocument!),
  ].join('|');

  String _documentKey(RoomEditorDocument document) => [
    for (final line in document.bundle.lines)
      '''
${line.id}:${line.startX}:${line.startY}:${line.length}:${line.plasterSelected}''',
    '#',
    for (final opening in document.bundle.openings)
      '''
${opening.id}:${opening.lineId}:${opening.type.name}:${opening.offsetFromStart}:${opening.width}:${opening.height}:${opening.sillHeight}''',
    '#',
    for (final constraint in document.constraints)
      '''
${constraint.lineId}:${constraint.type.name}:${constraint.targetValue ?? '-'}''',
  ].join(';');

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

  String _traceLabel(RoomEditorDragSolveRequest request) =>
      '#${request.traceId}'
      ' phase=${request.phase.name}'
      ' movedIndex=${request.movedIndex}'
      ' movedTarget=${request.movedTarget}';

  int _latencyMs(RoomEditorDragSolveRequest request) =>
      ((DateTime.now().microsecondsSinceEpoch - request.createdAtMicros) / 1000)
          .round();
}

RoomEditorSolverScheduler createRoomEditorSolverScheduler({
  required RoomEditorDragSolveCallback onEmit,
}) => impl.createRoomEditorSolverScheduler(onEmit: onEmit);
