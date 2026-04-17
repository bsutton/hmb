import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../room_editor.dart';
import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler.dart';

Set<RoomEditorConstraintKey> deriveConstraintConflictHighlightKeys({
  required List<RoomEditorConstraintViolation> solverViolations,
  Iterable<RoomEditorConstraintKey> requestedConstraintKeys = const [],
  int limit = 3,
}) {
  final requested = requestedConstraintKeys.toList(growable: false);
  final keys = <RoomEditorConstraintKey>{...requested};
  for (final violation in solverViolations) {
    if (keys.length >= limit + requested.length) {
      break;
    }
    keys.add(RoomEditorConstraintKey.fromConstraint(violation.constraint));
  }
  return keys;
}

({int first, int second})? parallelTargetLinesForSelection({
  required Set<int> selectedLineIndices,
  required int lineCount,
}) {
  if (selectedLineIndices.length != 2 || lineCount < 2) {
    return null;
  }
  final ordered = selectedLineIndices.toList()..sort();
  final first = ordered[0];
  final second = ordered[1];
  final adjacent =
      (first + 1) % lineCount == second || (second + 1) % lineCount == first;
  if (adjacent) {
    return null;
  }
  return (first: first, second: second);
}

({int source, int target}) chooseParallelConstraintDirection({
  required ({int first, int second}) pair,
  required List<RoomEditorLine> lines,
  required List<RoomEditorConstraint> constraints,
}) {
  int scoreForLine(int index) {
    final lineId = lines[index].id;
    var score = 0;
    for (final constraint in constraints) {
      if (constraint.lineId != lineId) {
        continue;
      }
      switch (constraint.type) {
        case RoomEditorConstraintType.lineLength:
          score += 3;
        case RoomEditorConstraintType.horizontal:
        case RoomEditorConstraintType.vertical:
          score += 3;
        case RoomEditorConstraintType.jointAngle:
          score += 2;
        case RoomEditorConstraintType.parallel:
          score += 1;
      }
    }
    return score;
  }

  final firstScore = scoreForLine(pair.first);
  final secondScore = scoreForLine(pair.second);
  if (firstScore == secondScore) {
    return (source: pair.first, target: pair.second);
  }
  return firstScore < secondScore
      ? (source: pair.first, target: pair.second)
      : (source: pair.second, target: pair.first);
}

Set<int> filterImplicitLengthConflictLineIndices({
  required Set<int> lineIndices,
  required List<RoomEditorLine> lines,
  required List<RoomEditorConstraint> constraints,
}) {
  final constrainedLineIds = {
    for (final constraint in constraints)
      if (constraint.type == RoomEditorConstraintType.lineLength)
        constraint.lineId,
  };
  return {
    for (final index in lineIndices)
      if (index >= 0 &&
          index < lines.length &&
          constrainedLineIds.contains(lines[index].id))
        index,
  };
}

RoomEditorConstraint? existingParallelConstraintForPair({
  required ({int first, int second}) pair,
  required List<RoomEditorLine> lines,
  required List<RoomEditorConstraint> constraints,
}) {
  final firstId = lines[pair.first].id;
  final secondId = lines[pair.second].id;
  for (final constraint in constraints) {
    if (constraint.type != RoomEditorConstraintType.parallel) {
      continue;
    }
    final targetId = constraint.targetValue;
    final matchesForward = constraint.lineId == firstId && targetId == secondId;
    final matchesReverse = constraint.lineId == secondId && targetId == firstId;
    if (matchesForward || matchesReverse) {
      return constraint;
    }
  }
  return null;
}

class RoomEditorWorkspace extends StatefulWidget {
  final RoomEditorDocument document;
  final bool landscape;
  final bool editorOnly;
  final bool showConstraintsInLandscape;
  final ValueChanged<RoomEditorDocument> onDocumentCommitted;
  final ValueChanged<RoomEditorCommand>? onCommand;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final RoomEditorSelectionController? selectionController;
  final RoomEditorHistoryController? historyController;
  final RoomEditorGridControlsMode gridControlsMode;
  final int? ceilingHeight;

  const RoomEditorWorkspace({
    required this.document,
    required this.onDocumentCommitted,
    super.key,
    this.onCommand,
    this.landscape = false,
    this.editorOnly = false,
    this.showConstraintsInLandscape = true,
    this.selectionController,
    this.historyController,
    this.onUndo,
    this.onRedo,
    this.gridControlsMode = RoomEditorGridControlsMode.none,
    this.ceilingHeight,
  });

  @override
  State<RoomEditorWorkspace> createState() => _RoomEditorWorkspaceState();
}

class _RoomEditorWorkspaceState extends State<RoomEditorWorkspace> {
  late RoomEditorDocument _document;
  var _snapToGrid = false;
  var _showGrid = false;
  var _showAllConstraints = false;
  var _fitCanvasRequest = 0;
  RoomEditorDocument? _cachedConstraintStateDocument;
  RoomEditorDocumentConstraintState? _cachedConstraintState;
  var _selection = const RoomEditorSelection.empty();
  RoomEditorDocument? _gestureBaseDocument;
  var _localHistory = const RoomEditorHistory();
  late final RoomEditorSolverScheduler _dragSolverScheduler;
  late final FocusNode _focusNode;
  int? _draggedIntersectionIndex;
  RoomEditorIntPoint? _draggedIntersectionTarget;
  int? _draggedLineIndex;
  Offset? _draggedLineDelta;
  RoomEditorDragSolveResult? _lastPreviewSolveResult;
  var _rigidDragNotificationShownForGesture = false;
  Map<RoomEditorConstraintKey, Offset> _constraintVisualOffsets = {};
  Set<RoomEditorConstraintKey> _highlightedConstraintKeys = {};
  Set<int> _highlightedImplicitLengthLineIndices = {};

  RoomEditorBundle get _bundle => _document.bundle;
  RoomEditorSelectionController? get _externalSelectionController =>
      widget.selectionController;
  RoomEditorHistoryController? get _historyController =>
      widget.historyController;
  RoomEditorHistory get _history => _historyController?.value ?? _localHistory;
  bool get _canUndo => _history.undoStack.isNotEmpty;
  bool get _canRedo => _history.redoStack.isNotEmpty;
  Set<int> get _selectedLineIndices => _selection.selectedLineIndices;
  Set<int> get _selectedIntersectionIndices =>
      _selection.selectedIntersectionIndices;

  int? get _selectedWallIndex {
    final lineIndex = _selection.selectedLineIndex;
    if (lineIndex != null &&
        lineIndex >= 0 &&
        lineIndex < _bundle.lines.length) {
      return lineIndex;
    }
    return null;
  }

  int? get _selectedIntersectionIndex {
    final intersectionIndex = _selection.selectedIntersectionIndex;
    if (intersectionIndex != null &&
        intersectionIndex >= 0 &&
        intersectionIndex < _bundle.lines.length) {
      return intersectionIndex;
    }
    return null;
  }

  RoomEditorDocumentConstraintState get _documentConstraintState {
    if (!identical(_cachedConstraintStateDocument, _document) ||
        _cachedConstraintState == null) {
      _cachedConstraintStateDocument = _document;
      _cachedConstraintState = deriveRoomEditorDocumentConstraintState(
        _document,
      );
    }
    return _cachedConstraintState!;
  }

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _focusNode = FocusNode(debugLabel: 'RoomEditorWorkspace');
    _selection = _normalizeSelection(
      _externalSelectionController?.value ?? const RoomEditorSelection.empty(),
      _document,
    );
    _constraintVisualOffsets = _pruneConstraintVisualOffsets(
      _constraintVisualOffsets,
      _document,
    );
    _dragSolverScheduler = createRoomEditorSolverScheduler(
      onEmit: (result) {
        if (!mounted) {
          return;
        }
        _maybeShowRigidDragNotification(result);
        if (result.solvedDocument == null) {
          return;
        }
        _lastPreviewSolveResult = result;
        _replaceDocument(result.solvedDocument!);
      },
    );
  }

  @override
  void didUpdateWidget(covariant RoomEditorWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _document = widget.document;
      _selection = _normalizeSelection(_selection, _document);
      _constraintVisualOffsets = _pruneConstraintVisualOffsets(
        _constraintVisualOffsets,
        _document,
      );
      _highlightedConstraintKeys = {
        for (final key in _highlightedConstraintKeys)
          if (_document.constraints.any(
            (constraint) =>
                RoomEditorConstraintKey.fromConstraint(constraint) == key,
          ))
            key,
      };
      _highlightedImplicitLengthLineIndices = {
        for (final index in _highlightedImplicitLengthLineIndices)
          if (index >= 0 && index < _document.bundle.lines.length) index,
      };
    }
    if (oldWidget.selectionController != widget.selectionController) {
      _selection = _normalizeSelection(
        _externalSelectionController?.value ?? _selection,
        _document,
      );
    }
    if (oldWidget.historyController != widget.historyController &&
        widget.historyController != null) {
      widget.historyController!.value = _history;
    }
    _externalSelectionController?.value = _selection;
  }

  void _setSelection(RoomEditorSelection selection) {
    final normalized = _normalizeSelection(selection, _document);
    setState(() {
      _selection = normalized;
    });
    _externalSelectionController?.value = normalized;
  }

  RoomEditorConstraint? _constraintForKey(RoomEditorConstraintKey key) {
    for (final constraint in _document.constraints) {
      if (RoomEditorConstraintKey.fromConstraint(constraint) == key) {
        return constraint;
      }
    }
    return null;
  }

  void _clearHighlightedConstraintsState() {
    _highlightedConstraintKeys = {};
    _highlightedImplicitLengthLineIndices = {};
  }

  void _clearHighlightedConstraints() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    if (_highlightedConstraintKeys.isEmpty) {
      return;
    }
    setState(_clearHighlightedConstraintsState);
  }

  Set<RoomEditorConstraintKey> _constraintKeysForViolations(
    List<RoomEditorConstraintViolation> violations, {
    int limit = 3,
  }) => {
    for (final violation in violations.take(limit))
      RoomEditorConstraintKey.fromConstraint(violation.constraint),
  };

  int? _lineIndexForConstraintKey(RoomEditorConstraintKey key) {
    final index = _bundle.lines.indexWhere((line) => line.id == key.lineId);
    return index >= 0 ? index : null;
  }

  String _constraintLabel(RoomEditorConstraintType type) => switch (type) {
    RoomEditorConstraintType.lineLength => 'length',
    RoomEditorConstraintType.horizontal => 'horizontal',
    RoomEditorConstraintType.vertical => 'vertical',
    RoomEditorConstraintType.jointAngle => 'angle',
    RoomEditorConstraintType.parallel => 'parallel',
  };

  String _constraintOwnerLabel(RoomEditorConstraintKey key) {
    final lineIndex = _lineIndexForConstraintKey(key);
    final wallLabel = lineIndex == null
        ? 'this wall'
        : 'wall W${lineIndex + 1}';
    return key.type == RoomEditorConstraintType.jointAngle
        ? 'the joint at $wallLabel'
        : wallLabel;
  }

  void _selectConstraint(RoomEditorConstraintKey key) {
    final lineIndex = _lineIndexForConstraintKey(key);
    if (lineIndex == null) {
      return;
    }
    final constraint = _constraintForKey(key);
    final selectedLineIndices = switch (key.type) {
      RoomEditorConstraintType.parallel => {
        lineIndex,
        if (constraint?.targetValue != null)
          _bundle.lines.indexWhere(
            (line) => line.id == constraint!.targetValue,
          ),
      }.where((index) => index >= 0).toSet(),
      RoomEditorConstraintType.jointAngle => <int>{},
      _ => {lineIndex},
    };
    _setSelection(
      RoomEditorSelection(
        selectedLineIndices: selectedLineIndices,
        selectedIntersectionIndex:
            key.type == RoomEditorConstraintType.jointAngle ? lineIndex : null,
        selectedConstraintKey: key,
      ),
    );
  }

  RoomEditorSelection _normalizeSelection(
    RoomEditorSelection selection,
    RoomEditorDocument document,
  ) => RoomEditorSelection(
    selectedLineIndices: {
      for (final index in selection.selectedLineIndices)
        if (index >= 0 && index < document.bundle.lines.length) index,
    },
    selectedIntersectionIndices: {
      for (final index in selection.selectedIntersectionIndices)
        if (index >= 0 && index < document.bundle.lines.length) index,
    },
    selectedOpeningIndex:
        selection.selectedOpeningIndex != null &&
            selection.selectedOpeningIndex! >= 0 &&
            selection.selectedOpeningIndex! < document.bundle.openings.length
        ? selection.selectedOpeningIndex
        : null,
    selectedConstraintKey:
        selection.selectedConstraintKey != null &&
            document.constraints.any(
              (constraint) =>
                  RoomEditorConstraintKey.fromConstraint(constraint) ==
                  selection.selectedConstraintKey,
            )
        ? selection.selectedConstraintKey
        : null,
  );

  Map<RoomEditorConstraintKey, Offset> _pruneConstraintVisualOffsets(
    Map<RoomEditorConstraintKey, Offset> offsets,
    RoomEditorDocument document,
  ) {
    final activeKeys = {
      for (final constraint in document.constraints)
        RoomEditorConstraintKey.fromConstraint(constraint),
    };
    return {
      for (final entry in offsets.entries)
        if (activeKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  bool _areAdjacentLines(int first, int second) {
    final count = _bundle.lines.length;
    if (count < 2) {
      return false;
    }
    return (first + 1) % count == second || (second + 1) % count == first;
  }

  int? _sharedIntersectionForSelectedLines() {
    if (_selectedLineIndices.length != 2) {
      return null;
    }
    final ordered = _selectedLineIndices.toList()..sort();
    final first = ordered[0];
    final second = ordered[1];
    if (!_areAdjacentLines(first, second)) {
      return null;
    }
    if ((first + 1) % _bundle.lines.length == second) {
      return second;
    }
    return first;
  }

  int? get _joinTargetIntersectionIndex =>
      _selectedIntersectionIndex ?? _sharedIntersectionForSelectedLines();

  int? get _angleTargetIntersectionIndex => _joinTargetIntersectionIndex;

  ({int first, int second})? get _parallelTargetLines =>
      parallelTargetLinesForSelection(
        selectedLineIndices: _selectedLineIndices,
        lineCount: _bundle.lines.length,
      );

  bool get _canSplit => _selectedLineIndices.length == 1;
  bool get _canJoin => _joinTargetIntersectionIndex != null;
  bool get _canSetAngle => _angleTargetIntersectionIndex != null;
  bool get _canSetParallel => _parallelTargetLines != null;

  List<RoomEditorConstraint> _constraintsWithoutLineType(
    List<RoomEditorConstraint> constraints,
    int lineId,
    RoomEditorConstraintType type,
  ) => [
    for (final constraint in constraints)
      if (!(constraint.lineId == lineId && constraint.type == type)) constraint,
  ];

  List<RoomEditorConstraint> _upsertConstraint(
    List<RoomEditorConstraint> constraints,
    RoomEditorConstraint nextConstraint,
  ) {
    final updated = _constraintsWithoutLineType(
      constraints,
      nextConstraint.lineId,
      nextConstraint.type,
    )..add(nextConstraint);
    return updated;
  }

  RoomEditorDocument _bundleWithAxisProjectedLine(
    RoomEditorDocument document,
    int lineIndex,
    RoomEditorConstraintType axisType, {
    required bool pinStart,
  }) {
    final lines = List<RoomEditorLine>.from(document.bundle.lines);
    final nextIndex = (lineIndex + 1) % lines.length;
    final start = lines[lineIndex];
    final end = RoomCanvasGeometry.lineEnd(lines, lineIndex);

    if (axisType == RoomEditorConstraintType.horizontal) {
      if (pinStart) {
        lines[nextIndex] = lines[nextIndex].copyWith(startY: start.startY);
      } else {
        lines[lineIndex] = lines[lineIndex].copyWith(startY: end.y);
      }
    } else if (axisType == RoomEditorConstraintType.vertical) {
      if (pinStart) {
        lines[nextIndex] = lines[nextIndex].copyWith(startX: start.startX);
      } else {
        lines[lineIndex] = lines[lineIndex].copyWith(startX: end.x);
      }
    }

    return document.copyWith(bundle: document.bundle.copyWith(lines: lines));
  }

  RoomEditorSolveResult _solveDocument(
    RoomEditorDocument document, {
    int? pinnedVertexIndex,
    RoomEditorIntPoint? pinnedVertexTarget,
    List<({int index, RoomEditorIntPoint target})> additionalPinnedVertices =
        const [],
  }) => RoomEditorConstraintSolver.solve(
    lines: document.bundle.lines,
    constraints: document.constraints,
    pinnedVertexIndex: pinnedVertexIndex,
    pinnedVertexTarget: pinnedVertexTarget,
    additionalPinnedVertices: additionalPinnedVertices,
  );

  void _replaceDocument(RoomEditorDocument document) {
    setState(() {
      _document = document;
      _selection = _normalizeSelection(_selection, document);
    });
    _externalSelectionController?.value = _selection;
  }

  void _setHistory(RoomEditorHistory history) {
    if (_historyController != null) {
      _historyController!.value = history;
      return;
    }
    _localHistory = history;
  }

  void _pushUndoState(RoomEditorDocument previous) {
    final history = _history;
    _setHistory(
      history.copyWith(
        undoStack: [...history.undoStack, previous],
        redoStack: const [],
      ),
    );
  }

  void _commitDocument(
    RoomEditorDocument document, {
    RoomEditorDocument? previousDocument,
    bool trackHistory = true,
  }) {
    final previous = previousDocument ?? _document;
    if (trackHistory && !_documentsEqual(previous, document)) {
      _pushUndoState(previous);
    }
    _replaceDocument(document);
    widget.onDocumentCommitted(document);
  }

  void _undoLocally() {
    if (!_canUndo) {
      return;
    }
    final history = _history;
    final previous = history.undoStack.last;
    final nextUndo = history.undoStack.sublist(0, history.undoStack.length - 1);
    _setHistory(
      history.copyWith(
        undoStack: nextUndo,
        redoStack: [...history.redoStack, _document],
      ),
    );
    _replaceDocument(previous);
    widget.onDocumentCommitted(previous);
  }

  void _redoLocally() {
    if (!_canRedo) {
      return;
    }
    final history = _history;
    final next = history.redoStack.last;
    final nextRedo = history.redoStack.sublist(0, history.redoStack.length - 1);
    _setHistory(
      history.copyWith(
        undoStack: [...history.undoStack, _document],
        redoStack: nextRedo,
      ),
    );
    _replaceDocument(next);
    widget.onDocumentCommitted(next);
  }

  Future<bool> _trySolveAndCommit(
    RoomEditorDocument document, {
    int? pinnedVertexIndex,
    RoomEditorIntPoint? pinnedVertexTarget,
    String? failureMessage,
    Set<RoomEditorConstraintKey> requestedConstraintKeys = const {},
    bool showFailureNotification = true,
  }) async {
    final requestedViolations =
        RoomEditorConstraintViolation.constraintViolations(
          document.bundle.lines,
          document.constraints,
        );
    final result = _solveDocument(
      document,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
    );
    if (!result.converged) {
      final displayResult = requestedConstraintKeys.isNotEmpty
          ? (result.violations.isNotEmpty
                ? result
                : RoomEditorSolveResult(
                    lines: document.bundle.lines,
                    converged: false,
                    maxError: requestedViolations.isEmpty
                        ? 0
                        : requestedViolations.first.error,
                    violations: requestedViolations,
                  ))
          : requestedViolations.isNotEmpty
          ? RoomEditorSolveResult(
              lines: document.bundle.lines,
              converged: false,
              maxError: requestedViolations.first.error,
              violations: requestedViolations,
            )
          : result;
      if (showFailureNotification) {
        _showConstraintConflictNotification(
          displayResult,
          failureMessage: failureMessage,
          requestedConstraintKeys: requestedConstraintKeys,
        );
      }
      return false;
    }
    final solved = document.copyWith(
      bundle: document.bundle.copyWith(lines: result.lines),
    );
    _commitDocument(solved);
    return true;
  }

  void _beginGestureEdit() {
    _clearHighlightedConstraints();
    _gestureBaseDocument ??= _document;
    _draggedIntersectionIndex = null;
    _draggedIntersectionTarget = null;
    _draggedLineIndex = null;
    _draggedLineDelta = null;
    _lastPreviewSolveResult = null;
    _rigidDragNotificationShownForGesture = false;
  }

  Future<void> _commitGestureEdit() async {
    final commitStartedAtMicros = DateTime.now().microsecondsSinceEpoch;
    final baseDocument = _gestureBaseDocument;
    _gestureBaseDocument = null;
    _dragSolverScheduler.cancel();
    final draggedIntersectionIndex = _draggedIntersectionIndex;
    final draggedIntersectionTarget = _draggedIntersectionTarget;
    final draggedLineIndex = _draggedLineIndex;
    final draggedLineDelta = _draggedLineDelta;
    _draggedIntersectionIndex = null;
    _draggedIntersectionTarget = null;
    _draggedLineIndex = null;
    _draggedLineDelta = null;
    if (draggedIntersectionIndex != null && draggedIntersectionTarget != null) {
      final finalResult =
          _reusePreviewSolveResult(
            draggedIntersectionIndex,
            draggedIntersectionTarget,
          ) ??
          (() {
            debugPrint(
              '[room_drag] commit solve requested'
              ' movedIndex=$draggedIntersectionIndex'
              ' movedTarget=$draggedIntersectionTarget',
            );
            final commitStopwatch = Stopwatch()..start();
            final result = RoomEditorDragSolver.solve(
              RoomEditorDragSolveRequest(
                currentDocument: _document,
                gestureBaseDocument: baseDocument,
                movedIndex: draggedIntersectionIndex,
                movedTarget: draggedIntersectionTarget,
                emitDistanceThreshold: RoomCanvasGeometry.defaultGridSize(
                  _bundle.unitSystem,
                ).toDouble(),
                phase: RoomEditorDragSolvePhase.commit,
                createdAtMicros: commitStartedAtMicros,
              ),
            );
            commitStopwatch.stop();
            debugPrint(
              '[room_drag] commit solve completed'
              ' traceId=${result.request.traceId}'
              ' solved=${result.solvedDocument != null}'
              ' solveDuration=${commitStopwatch.elapsedMilliseconds}ms'
              ''' totalLag=${((DateTime.now().microsecondsSinceEpoch - commitStartedAtMicros) / 1000).round()}ms''',
            );
            return result;
          })();
      _maybeShowRigidDragNotification(finalResult);
      if (finalResult.solvedDocument != null) {
        _replaceDocument(finalResult.solvedDocument!);
      }
    }
    if (draggedLineIndex != null && draggedLineDelta != null) {
      final solved = _solveTranslatedLineDocument(
        baseDocument ?? _document,
        draggedLineIndex,
        draggedLineDelta,
      );
      if (solved != null) {
        _replaceDocument(solved);
      }
    }
    _lastPreviewSolveResult = null;
    debugPrint(
      '[room_drag] commit document=${_formatLines(_document.bundle.lines)}',
    );
    if (baseDocument != null) {
      _commitDocument(_document, previousDocument: baseDocument);
      return;
    }
    widget.onDocumentCommitted(_document);
  }

  RoomEditorDocument? _solveTranslatedLineDocument(
    RoomEditorDocument sourceDocument,
    int lineIndex,
    Offset worldDelta,
  ) {
    final lines = List<RoomEditorLine>.from(sourceDocument.bundle.lines);
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return null;
    }
    final nextIndex = (lineIndex + 1) % lines.length;
    final start = lines[lineIndex];
    final end = RoomCanvasGeometry.lineEnd(lines, lineIndex);
    final translatedStart = RoomEditorIntPoint(
      start.startX + worldDelta.dx.round(),
      start.startY + worldDelta.dy.round(),
    );
    final translatedEnd = RoomEditorIntPoint(
      end.x + worldDelta.dx.round(),
      end.y + worldDelta.dy.round(),
    );
    lines[lineIndex] = lines[lineIndex].copyWith(
      startX: translatedStart.x,
      startY: translatedStart.y,
    );
    lines[nextIndex] = lines[nextIndex].copyWith(
      startX: translatedEnd.x,
      startY: translatedEnd.y,
    );
    final candidate = sourceDocument.copyWith(
      bundle: sourceDocument.bundle.copyWith(lines: lines),
    );
    final result = _solveDocument(
      candidate,
      pinnedVertexIndex: lineIndex,
      pinnedVertexTarget: translatedStart,
      additionalPinnedVertices: [(index: nextIndex, target: translatedEnd)],
    );
    if (!result.converged) {
      return null;
    }
    return candidate.copyWith(
      bundle: candidate.bundle.copyWith(lines: result.lines),
    );
  }

  void _moveLineLocally(int lineIndex, Offset worldDelta) {
    final baseDocument = _gestureBaseDocument ?? _document;
    _draggedLineIndex = lineIndex;
    _draggedLineDelta = worldDelta;
    final solved = _solveTranslatedLineDocument(
      baseDocument,
      lineIndex,
      worldDelta,
    );
    if (solved != null) {
      _replaceDocument(solved);
    }
  }

  RoomEditorDragSolveResult? _reusePreviewSolveResult(
    int draggedIntersectionIndex,
    RoomEditorIntPoint draggedIntersectionTarget,
  ) {
    final previewResult = _lastPreviewSolveResult;
    if (previewResult == null || previewResult.solvedDocument == null) {
      return null;
    }
    final request = previewResult.request;
    if (request.phase != RoomEditorDragSolvePhase.preview ||
        request.movedIndex != draggedIntersectionIndex ||
        request.movedTarget.x != draggedIntersectionTarget.x ||
        request.movedTarget.y != draggedIntersectionTarget.y) {
      return null;
    }
    debugPrint(
      '[room_drag] reusing preview solve result'
      ' traceId=${request.traceId}'
      ' movedIndex=$draggedIntersectionIndex'
      ' movedTarget=$draggedIntersectionTarget',
    );
    return previewResult;
  }

  void _maybeShowRigidDragNotification(RoomEditorDragSolveResult result) {
    final blockedByConstraints =
        result.rigidConstraintClamp || result.solvedDocument == null;
    if (_rigidDragNotificationShownForGesture || !blockedByConstraints) {
      return;
    }
    _rigidDragNotificationShownForGesture = true;
    final attemptedDocument = _attemptedDocumentForDragResult(result);
    final implicitLengthConflicts = attemptedDocument == null
        ? <int>{}
        : filterImplicitLengthConflictLineIndices(
            lineIndices: _implicitLengthConflictLineIndicesForDragResult(
              result,
              attemptedDocument,
            ),
            lines: _bundle.lines,
            constraints: _document.constraints,
          );
    setState(() {
      _highlightedImplicitLengthLineIndices = implicitLengthConflicts;
      _highlightedConstraintKeys = attemptedDocument == null
          ? {}
          : implicitLengthConflicts.isNotEmpty
          ? _lineLengthConstraintKeysForLineIndices(implicitLengthConflicts)
          : _constraintKeysForViolations(
              RoomEditorConstraintViolation.constraintViolations(
                attemptedDocument.bundle.lines,
                attemptedDocument.constraints,
              ),
            );
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    final message = implicitLengthConflicts.isNotEmpty
        ? 'Blocked by current constraints: moving this corner would change wall lengths on ${_wallListLabel(implicitLengthConflicts)}.'
        : 'This room is rigid. Remove one or more constraints to modify the room.';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  void _showJoinBlockedNotification(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  void _showConstraintConflictNotification(
    RoomEditorSolveResult result, {
    String? failureMessage,
    Set<RoomEditorConstraintKey> requestedConstraintKeys = const {},
  }) {
    setState(() {
      _highlightedImplicitLengthLineIndices = {};
      _highlightedConstraintKeys = requestedConstraintKeys.isEmpty
          ? _constraintKeysForViolations(result.violations)
          : deriveConstraintConflictHighlightKeys(
              solverViolations: result.violations,
              requestedConstraintKeys: requestedConstraintKeys,
            );
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    final details = result.violations
        .take(3)
        .map((violation) {
          final key = RoomEditorConstraintKey.fromConstraint(
            violation.constraint,
          );
          final ownerLabel = _constraintOwnerLabel(key);
          final constraintLabel = _constraintLabel(violation.constraint.type);
          return '$constraintLabel on $ownerLabel';
        })
        .join(', ');
    final message = details.isEmpty
        ? (failureMessage ??
              'This action conflicts with the current constraints.')
        : '${failureMessage ?? 'Blocked by current constraints'}: $details.';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Set<int> _implicitLengthConflictLineIndicesForDragResult(
    RoomEditorDragSolveResult result,
    RoomEditorDocument attemptedDocument,
  ) {
    final sourceDocument =
        result.request.gestureBaseDocument ?? result.request.currentDocument;
    return deriveImplicitLengthConflictLineIndices(
      sourceDocument: sourceDocument,
      attemptedDocument: attemptedDocument,
      movedVertexIndex: result.request.movedIndex,
    );
  }

  Set<RoomEditorConstraintKey> _lineLengthConstraintKeysForLineIndices(
    Iterable<int> lineIndices,
  ) => {
    for (final lineIndex in lineIndices)
      if (lineIndex >= 0 && lineIndex < _bundle.lines.length)
        for (final constraint in _document.constraints)
          if (constraint.lineId == _bundle.lines[lineIndex].id &&
              constraint.type == RoomEditorConstraintType.lineLength)
            RoomEditorConstraintKey.fromConstraint(constraint),
  };

  String _wallListLabel(Iterable<int> lineIndices) {
    final labels = [
      for (final index in lineIndices.toList()..sort()) 'W${index + 1}',
    ];
    if (labels.isEmpty) {
      return '';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    if (labels.length == 2) {
      return '${labels.first} and ${labels.last}';
    }
    return '${labels.sublist(0, labels.length - 1).join(', ')}, and ${labels.last}';
  }

  RoomEditorDocument? _attemptedDocumentForDragResult(
    RoomEditorDragSolveResult result,
  ) {
    final request = result.request;
    final source = request.gestureBaseDocument ?? request.currentDocument;
    final lines = List<RoomEditorLine>.from(source.bundle.lines);
    if (request.movedIndex < 0 || request.movedIndex >= lines.length) {
      return null;
    }
    lines[request.movedIndex] = lines[request.movedIndex].copyWith(
      startX: request.movedTarget.x,
      startY: request.movedTarget.y,
    );
    return source.copyWith(bundle: source.bundle.copyWith(lines: lines));
  }

  String _formatPoint(RoomEditorIntPoint? point) =>
      point == null ? '<none>' : '(${point.x},${point.y})';

  String _formatLines(List<RoomEditorLine>? lines) {
    if (lines == null) {
      return '<none>';
    }
    return [
      for (var i = 0; i < lines.length; i++)
        {
          '$i:${lines[i].id}@(${lines[i].startX},${lines[i].startY})',
          '->${_formatPoint(RoomCanvasGeometry.lineEnd(lines, i))}',
        },
    ].join(' | ');
  }

  void _moveOpeningLocally(
    int index,
    RoomEditorIntPoint point,
    int anchorOffset,
  ) {
    final opening = _bundle.openings[index];
    final lineIndex = _bundle.lines.indexWhere(
      (line) => line.id == opening.lineId,
    );
    if (lineIndex < 0) {
      return;
    }
    final line = _bundle.lines[lineIndex];
    final end = RoomCanvasGeometry.lineEnd(_bundle.lines, lineIndex);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return;
    }
    final projected =
        ((point.x - line.startX) * dx + (point.y - line.startY) * dy) /
        lengthSquared;
    final offset = (projected * line.length).round() - anchorOffset;
    final maxOffset = max(0, line.length - opening.width);
    final openings = List<RoomEditorOpening>.from(_bundle.openings);
    openings[index] = opening.copyWith(
      offsetFromStart: offset.clamp(0, maxOffset),
    );
    _replaceDocument(
      _document.copyWith(bundle: _bundle.copyWith(openings: openings)),
    );
  }

  Future<void> _setAxisConstraint(
    int index,
    RoomEditorConstraintType axisType,
  ) async {
    final line = _bundle.lines[index];
    final key = RoomEditorConstraintKey(lineId: line.id, type: axisType);
    final existing = _document.constraints.any(
      (constraint) =>
          constraint.lineId == line.id && constraint.type == axisType,
    );
    if (existing) {
      _selectConstraint(key);
      return;
    }
    final opposing = axisType == RoomEditorConstraintType.horizontal
        ? RoomEditorConstraintType.vertical
        : RoomEditorConstraintType.horizontal;
    final constraints = !existing
        ? _upsertConstraint(
            _constraintsWithoutLineType(
              _constraintsWithoutLineType(
                _document.constraints,
                line.id,
                opposing,
              ),
              line.id,
              axisType,
            ),
            RoomEditorConstraint(lineId: line.id, type: axisType),
          )
        : _constraintsWithoutLineType(_document.constraints, line.id, axisType);
    final document = _document.copyWith(constraints: constraints);

    final lineEnd = RoomCanvasGeometry.lineEnd(_bundle.lines, index);
    final nextIndex = (index + 1) % _bundle.lines.length;
    final startPinnedDocument = _bundleWithAxisProjectedLine(
      document,
      index,
      axisType,
      pinStart: true,
    );
    final endPinnedDocument = _bundleWithAxisProjectedLine(
      document,
      index,
      axisType,
      pinStart: false,
    );
    final solved =
        await _trySolveAndCommit(
          startPinnedDocument,
          pinnedVertexIndex: index,
          pinnedVertexTarget: RoomEditorIntPoint(line.startX, line.startY),
          requestedConstraintKeys: {key},
          showFailureNotification: false,
        ) ||
        await _trySolveAndCommit(
          endPinnedDocument,
          pinnedVertexIndex: nextIndex,
          pinnedVertexTarget: lineEnd,
          requestedConstraintKeys: {key},
          showFailureNotification: false,
        ) ||
        await _trySolveAndCommit(document, requestedConstraintKeys: {key});
    if (solved && mounted) {
      _selectConstraint(key);
    }
  }

  int _nextLineId(List<RoomEditorLine> lines) {
    var maxId = 0;
    for (final line in lines) {
      if (line.id > maxId) {
        maxId = line.id;
      }
    }
    return maxId + 1;
  }

  int _nextOpeningId(List<RoomEditorOpening> openings) {
    var maxId = 0;
    for (final opening in openings) {
      if (opening.id > maxId) {
        maxId = opening.id;
      }
    }
    return maxId + 1;
  }

  Future<void> _splitSelectedLineLocally() async {
    final lineIndex = _selectedWallIndex;
    if (lineIndex == null) {
      return;
    }
    final lines = List<RoomEditorLine>.from(_bundle.lines);
    final line = lines[lineIndex];
    final end = RoomCanvasGeometry.lineEnd(lines, lineIndex);
    if (line.startX == end.x && line.startY == end.y) {
      return;
    }
    final midpoint = RoomEditorIntPoint(
      ((line.startX + end.x) / 2).round(),
      ((line.startY + end.y) / 2).round(),
    );
    final insertedLine = RoomEditorLine(
      id: _nextLineId(lines),
      seqNo: 0,
      startX: midpoint.x,
      startY: midpoint.y,
      length: 0,
      plasterSelected: line.plasterSelected,
    );
    final updatedLines = <RoomEditorLine>[];
    for (var i = 0; i < lines.length; i++) {
      updatedLines.add(lines[i]);
      if (i == lineIndex) {
        updatedLines.add(insertedLine);
      }
    }
    final normalizedLines = RoomCanvasGeometry.normalizeSeq(updatedLines);
    final horizontalConstraint = _constraintForKey(
      RoomEditorConstraintKey(
        lineId: line.id,
        type: RoomEditorConstraintType.horizontal,
      ),
    );
    final verticalConstraint = _constraintForKey(
      RoomEditorConstraintKey(
        lineId: line.id,
        type: RoomEditorConstraintType.vertical,
      ),
    );
    var constraints = _document.constraints.where((constraint) {
      if (constraint.lineId != line.id) {
        return true;
      }
      return constraint.type == RoomEditorConstraintType.horizontal ||
          constraint.type == RoomEditorConstraintType.vertical;
    }).toList();
    if (horizontalConstraint != null) {
      constraints = _upsertConstraint(
        constraints,
        RoomEditorConstraint(
          lineId: insertedLine.id,
          type: RoomEditorConstraintType.horizontal,
        ),
      );
    }
    if (verticalConstraint != null) {
      constraints = _upsertConstraint(
        constraints,
        RoomEditorConstraint(
          lineId: insertedLine.id,
          type: RoomEditorConstraintType.vertical,
        ),
      );
    }
    final solved = await _trySolveAndCommit(
      _document.copyWith(
        bundle: _bundle.copyWith(lines: normalizedLines),
        constraints: constraints,
      ),
    );
    if (solved && mounted) {
      _setSelection(RoomEditorSelection(selectedLineIndex: lineIndex));
    }
  }

  Future<void> _joinSelectedIntersectionLocally() async {
    final intersectionIndex = _joinTargetIntersectionIndex;
    if (intersectionIndex == null) {
      return;
    }
    if (_bundle.lines.length <= 4) {
      _showJoinBlockedNotification(
        'This corner cannot be removed. A room needs at least four corners.',
      );
      return;
    }
    final removedLineId = _bundle.lines[intersectionIndex].id;
    final updatedLines = RoomCanvasGeometry.normalizeSeq(
      List<RoomEditorLine>.from(_bundle.lines)..removeAt(intersectionIndex),
    );
    final constraints = [
      for (final constraint in _document.constraints)
        if (constraint.lineId != removedLineId) constraint,
    ];
    final solved = await _trySolveAndCommit(
      _document.copyWith(
        bundle: _bundle.copyWith(lines: updatedLines),
        constraints: constraints,
      ),
      failureMessage:
          'This corner cannot be removed with the current constraints',
    );
    if (!solved) {
      return;
    }
    if (mounted) {
      _setSelection(
        RoomEditorSelection(
          selectedIntersectionIndex: intersectionIndex.clamp(
            0,
            _bundle.lines.length - 1,
          ),
        ),
      );
    }
  }

  Future<void> _emitLengthCommand() async {
    final lineIndex = _selectedWallIndex;
    if (lineIndex == null) {
      return;
    }
    final line = _bundle.lines[lineIndex];
    final existing = _constraintForKey(
      RoomEditorConstraintKey(
        lineId: line.id,
        type: RoomEditorConstraintType.lineLength,
      ),
    );
    final length = await showRoomEditorLengthDialog(
      context: context,
      unitSystem: _bundle.unitSystem,
      initialValue: existing?.targetValue ?? line.length,
    );
    if (length == null || !mounted) {
      return;
    }
    await _setLocalLineLengthConstraint(lineIndex, length);
  }

  Future<void> _setLocalLineLengthConstraint(int lineIndex, int length) async {
    final line = _bundle.lines[lineIndex];
    final key = RoomEditorConstraintKey(
      lineId: line.id,
      type: RoomEditorConstraintType.lineLength,
    );
    final constraints = _upsertConstraint(
      _document.constraints,
      RoomEditorConstraint(
        lineId: line.id,
        type: RoomEditorConstraintType.lineLength,
        targetValue: length,
      ),
    );
    final solved = await _trySolveAndCommit(
      _document.copyWith(constraints: constraints),
      requestedConstraintKeys: {key},
    );
    if (solved && mounted) {
      _selectConstraint(key);
    }
  }

  Future<void> _deleteConstraintByKey(RoomEditorConstraintKey key) async {
    final constraint = _constraintForKey(key);
    if (constraint == null) {
      return;
    }
    final constraints = _constraintsWithoutLineType(
      _document.constraints,
      key.lineId,
      key.type,
    );
    final solved = await _trySolveAndCommit(
      _document.copyWith(constraints: constraints),
    );
    if (!solved || !mounted) {
      return;
    }
    setState(() {
      _constraintVisualOffsets = Map.of(_constraintVisualOffsets)..remove(key);
    });
    _setSelection(
      RoomEditorSelection(
        selectedLineIndex: key.type == RoomEditorConstraintType.jointAngle
            ? null
            : _lineIndexForConstraintKey(key),
        selectedIntersectionIndex:
            key.type == RoomEditorConstraintType.jointAngle
            ? _lineIndexForConstraintKey(key)
            : null,
      ),
    );
  }

  Future<void> _confirmDeleteConstraint(RoomEditorConstraintKey key) async {
    final constraintLabel = _constraintLabel(key.type);
    final ownerLabel = _constraintOwnerLabel(key);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Constraint'),
        content: Text(
          'Delete the $constraintLabel constraint from $ownerLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await _deleteConstraintByKey(key);
    }
  }

  void _moveConstraintVisual(RoomEditorConstraintKey key, Offset worldOffset) {
    setState(() {
      _constraintVisualOffsets = Map.of(_constraintVisualOffsets)
        ..[key] = worldOffset;
    });
  }

  void _handleDeleteShortcut() {
    final key = _selection.selectedConstraintKey;
    if (key == null) {
      return;
    }
    unawaited(_deleteConstraintByKey(key));
  }

  bool _documentsEqual(RoomEditorDocument left, RoomEditorDocument right) {
    if (left.bundle.roomName != right.bundle.roomName ||
        left.bundle.unitSystem != right.bundle.unitSystem ||
        left.bundle.plasterCeiling != right.bundle.plasterCeiling ||
        left.bundle.lines.length != right.bundle.lines.length ||
        left.bundle.openings.length != right.bundle.openings.length ||
        left.constraints.length != right.constraints.length) {
      return false;
    }
    for (var i = 0; i < left.bundle.lines.length; i++) {
      final a = left.bundle.lines[i];
      final b = right.bundle.lines[i];
      if (a.id != b.id ||
          a.seqNo != b.seqNo ||
          a.startX != b.startX ||
          a.startY != b.startY ||
          a.length != b.length ||
          a.plasterSelected != b.plasterSelected) {
        return false;
      }
    }
    for (var i = 0; i < left.bundle.openings.length; i++) {
      final a = left.bundle.openings[i];
      final b = right.bundle.openings[i];
      if (a.id != b.id ||
          a.lineId != b.lineId ||
          a.type != b.type ||
          a.offsetFromStart != b.offsetFromStart ||
          a.width != b.width ||
          a.height != b.height ||
          a.sillHeight != b.sillHeight) {
        return false;
      }
    }
    for (var i = 0; i < left.constraints.length; i++) {
      final a = left.constraints[i];
      final b = right.constraints[i];
      if (a.lineId != b.lineId ||
          a.type != b.type ||
          a.targetValue != b.targetValue) {
        return false;
      }
    }
    return true;
  }

  Future<void> _emitOpeningCommand(RoomEditorOpeningType type) async {
    final lineIndex = _selection.selectedLineIndex;
    if (lineIndex == null) {
      return;
    }
    final opening = await showRoomEditorOpeningDialog(
      context: context,
      unitSystem: _bundle.unitSystem,
      type: type,
      maxWidth: _bundle.lines[lineIndex].length,
      maxHeight: widget.ceilingHeight,
    );
    if (opening == null || !mounted) {
      return;
    }
    await _addOpeningLocally(lineIndex, opening);
  }

  Future<void> _emitEditOpeningCommand() async {
    final openingIndex = _selection.selectedOpeningIndex;
    if (openingIndex == null) {
      return;
    }
    final opening = _bundle.openings[openingIndex];
    final lineIndex = _bundle.lines.indexWhere(
      (line) => line.id == opening.lineId,
    );
    final updated = await showRoomEditorOpeningDialog(
      context: context,
      unitSystem: _bundle.unitSystem,
      type: opening.type,
      maxWidth: lineIndex == -1 ? null : _bundle.lines[lineIndex].length,
      maxHeight: widget.ceilingHeight,
      initialOpening: RoomEditorOpeningDraft(
        type: opening.type,
        width: opening.width,
        height: opening.height,
        sillHeight: opening.sillHeight,
      ),
      title: opening.type == RoomEditorOpeningType.door
          ? 'Edit Door'
          : 'Edit Window',
      confirmLabel: 'Save',
    );
    if (updated == null || !mounted) {
      return;
    }
    await _editOpeningLocally(openingIndex, updated);
  }

  Future<void> _addOpeningLocally(
    int lineIndex,
    RoomEditorOpeningDraft openingDraft,
  ) async {
    final line = _bundle.lines[lineIndex];
    final centeredOffset = max(0, (line.length - openingDraft.width) ~/ 2);
    final maxOffset = max(0, line.length - openingDraft.width);
    final nextOpening = RoomEditorOpening(
      id: _nextOpeningId(_bundle.openings),
      lineId: line.id,
      type: openingDraft.type,
      offsetFromStart: centeredOffset.clamp(0, maxOffset),
      width: openingDraft.width,
      height: openingDraft.height,
      sillHeight: openingDraft.sillHeight,
    );
    final next = _document.copyWith(
      bundle: _bundle.copyWith(openings: [..._bundle.openings, nextOpening]),
    );
    _commitDocument(next);
    if (mounted) {
      _setSelection(
        RoomEditorSelection(selectedOpeningIndex: _bundle.openings.length - 1),
      );
    }
  }

  Future<void> _editOpeningLocally(
    int openingIndex,
    RoomEditorOpeningDraft openingDraft,
  ) async {
    if (openingIndex < 0 || openingIndex >= _bundle.openings.length) {
      return;
    }
    final existing = _bundle.openings[openingIndex];
    final lineIndex = _bundle.lines.indexWhere(
      (line) => line.id == existing.lineId,
    );
    if (lineIndex == -1) {
      return;
    }
    final line = _bundle.lines[lineIndex];
    final maxOffset = max(0, line.length - openingDraft.width);
    final openings = List<RoomEditorOpening>.from(_bundle.openings);
    openings[openingIndex] = existing.copyWith(
      type: openingDraft.type,
      width: openingDraft.width,
      height: openingDraft.height,
      sillHeight: openingDraft.sillHeight,
      offsetFromStart: existing.offsetFromStart.clamp(0, maxOffset),
    );
    _commitDocument(
      _document.copyWith(bundle: _bundle.copyWith(openings: openings)),
    );
    if (mounted) {
      _setSelection(RoomEditorSelection(selectedOpeningIndex: openingIndex));
    }
  }

  void _deleteSelectedOpeningLocally() {
    final openingIndex = _selection.selectedOpeningIndex;
    if (openingIndex == null ||
        openingIndex < 0 ||
        openingIndex >= _bundle.openings.length) {
      return;
    }
    final openings = List<RoomEditorOpening>.from(_bundle.openings)
      ..removeAt(openingIndex);
    _commitDocument(
      _document.copyWith(bundle: _bundle.copyWith(openings: openings)),
    );
    _setSelection(const RoomEditorSelection.empty());
  }

  Future<void> _emitAngleCommand({int? fixedAngle}) async {
    final intersectionIndex = _angleTargetIntersectionIndex;
    if (intersectionIndex == null) {
      return;
    }
    final line = _bundle.lines[intersectionIndex];
    final key = RoomEditorConstraintKey(
      lineId: line.id,
      type: RoomEditorConstraintType.jointAngle,
    );
    final angleConstraint = _constraintForKey(key);
    final angle =
        fixedAngle ??
        await showRoomEditorAngleDialog(
          context: context,
          initialValue:
              angleConstraint?.targetValue ??
              RoomEditorConstraintSolver.currentAngleValue(
                _bundle.lines,
                intersectionIndex,
              ),
        );
    if (angle == null || !mounted) {
      return;
    }
    if (widget.onCommand == null) {
      final constraints = _upsertConstraint(
        _document.constraints,
        RoomEditorConstraint(
          lineId: line.id,
          type: RoomEditorConstraintType.jointAngle,
          targetValue: angle,
        ),
      );
      final solved = await _trySolveAndCommit(
        _document.copyWith(constraints: constraints),
        requestedConstraintKeys: {key},
      );
      if (solved && mounted) {
        _selectConstraint(key);
      }
      return;
    }
    widget.onCommand!(
      RoomEditorCommand(
        type: RoomEditorCommandType.setAngle,
        document: _document,
        intersectionIndex: intersectionIndex,
        intValue: angle,
      ),
    );
  }

  Future<void> _setParallelConstraint() async {
    final pair = _parallelTargetLines;
    if (pair == null) {
      return;
    }
    final existing = existingParallelConstraintForPair(
      pair: pair,
      lines: _bundle.lines,
      constraints: _document.constraints,
    );
    if (existing != null) {
      _clearHighlightedConstraints();
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      _selectConstraint(RoomEditorConstraintKey.fromConstraint(existing));
      return;
    }
    final direction = chooseParallelConstraintDirection(
      pair: pair,
      lines: _bundle.lines,
      constraints: _document.constraints,
    );
    final sourceLine = _bundle.lines[direction.source];
    final targetLine = _bundle.lines[direction.target];
    final key = RoomEditorConstraintKey(
      lineId: sourceLine.id,
      type: RoomEditorConstraintType.parallel,
    );
    final constraints = [
      for (final constraint in _document.constraints)
        if (!(constraint.type == RoomEditorConstraintType.parallel &&
            ((constraint.lineId == sourceLine.id &&
                    constraint.targetValue == targetLine.id) ||
                (constraint.lineId == targetLine.id &&
                    constraint.targetValue == sourceLine.id))))
          constraint,
      RoomEditorConstraint(
        lineId: sourceLine.id,
        type: RoomEditorConstraintType.parallel,
        targetValue: targetLine.id,
      ),
    ];
    final solved = await _trySolveAndCommit(
      _document.copyWith(constraints: constraints),
      requestedConstraintKeys: {key},
    );
    if (solved && mounted) {
      _selectConstraint(key);
    }
  }

  Widget _buildToolbar({
    required bool vertical,
    required bool wrap,
    bool constraintsOnly = false,
    bool excludeConstraints = false,
  }) {
    final effectiveLineIndex = _selectedWallIndex;
    final hasLine = effectiveLineIndex != null;
    final hasOpening =
        _selection.selectedOpeningIndex != null &&
        _selection.selectedOpeningIndex! < _bundle.openings.length;
    final selectedLine = hasLine ? _bundle.lines[effectiveLineIndex] : null;
    final selectedOpening = hasOpening
        ? _bundle.openings[_selection.selectedOpeningIndex!]
        : null;
    final hasLineLengthConstraint =
        selectedLine != null &&
        _document.constraints.any(
          (constraint) =>
              constraint.lineId == selectedLine.id &&
              constraint.type == RoomEditorConstraintType.lineLength,
        );
    final hasHorizontalConstraint =
        selectedLine != null &&
        _document.constraints.any(
          (constraint) =>
              constraint.lineId == selectedLine.id &&
              constraint.type == RoomEditorConstraintType.horizontal,
        );
    final hasVerticalConstraint =
        selectedLine != null &&
        _document.constraints.any(
          (constraint) =>
              constraint.lineId == selectedLine.id &&
              constraint.type == RoomEditorConstraintType.vertical,
        );
    final selectedIntersectionLine = _angleTargetIntersectionIndex != null
        ? _bundle.lines[_angleTargetIntersectionIndex!]
        : null;
    final hasAngleConstraint =
        selectedIntersectionLine != null &&
        _document.constraints.any(
          (constraint) =>
              constraint.lineId == selectedIntersectionLine.id &&
              constraint.type == RoomEditorConstraintType.jointAngle,
        );
    final actions = buildRoomEditorToolbarActions(
      state: RoomEditorToolbarState(
        gridControlsMode: widget.gridControlsMode,
        snapToGrid: _snapToGrid,
        showGrid: _showGrid,
        selectedLineCount: _selectedLineIndices.length,
        selectedIntersectionCount: _selectedIntersectionIndices.length,
        hasOpening: hasOpening,
        canSplit: _canSplit,
        canJoin: _canJoin,
        hasLineLengthConstraint: hasLineLengthConstraint,
        hasHorizontalConstraint: hasHorizontalConstraint,
        hasVerticalConstraint: hasVerticalConstraint,
        hasAngleConstraint: hasAngleConstraint,
        canSetAngle: _canSetAngle,
        canSetRightAngle: _canSetAngle,
        canSetParallel: _canSetParallel,
        showAllConstraints: _showAllConstraints,
        areSelectedLinesIncluded:
            _selectedLineIndices.isNotEmpty &&
            _selectedLineIndices.every(
              (index) => _bundle.lines[index].plasterSelected,
            ),
        isSelectedOpeningDoor:
            selectedOpening?.type == RoomEditorOpeningType.door,
      ),
      callbacks: RoomEditorToolbarCallbacks(
        onUndo: _canUndo ? _undoLocally : null,
        onRedo: _canRedo ? _redoLocally : null,
        onFit: () => setState(() {
          _clearHighlightedConstraintsState();
          _fitCanvasRequest++;
        }),
        onToggleSnapToGrid: () => setState(() {
          _clearHighlightedConstraintsState();
          _snapToGrid = !_snapToGrid;
        }),
        onToggleShowGrid: () => setState(() {
          _clearHighlightedConstraintsState();
          _showGrid = !_showGrid;
          if (!_showGrid) {
            _snapToGrid = false;
          }
        }),
        onDeselect: () {
          _clearHighlightedConstraints();
          _setSelection(const RoomEditorSelection.empty());
        },
        onSplit: _canSplit
            ? () {
                _clearHighlightedConstraints();
                unawaited(_splitSelectedLineLocally());
              }
            : null,
        onAddDoor: hasLine
            ? () {
                _clearHighlightedConstraints();
                unawaited(_emitOpeningCommand(RoomEditorOpeningType.door));
              }
            : null,
        onAddWindow: hasLine
            ? () {
                _clearHighlightedConstraints();
                unawaited(_emitOpeningCommand(RoomEditorOpeningType.window));
              }
            : null,
        onEditOpening: hasOpening
            ? () {
                _clearHighlightedConstraints();
                unawaited(_emitEditOpeningCommand());
              }
            : null,
        onDeleteOpening: hasOpening
            ? () {
                _clearHighlightedConstraints();
                _deleteSelectedOpeningLocally();
              }
            : null,
        onToggleLinePlaster: _selectedLineIndices.isNotEmpty
            ? () {
                _clearHighlightedConstraints();
                final lines = List<RoomEditorLine>.from(_bundle.lines);
                final include = !_selectedLineIndices.every(
                  (index) => lines[index].plasterSelected,
                );
                for (final index in _selectedLineIndices) {
                  final line = lines[index];
                  lines[index] = line.copyWith(plasterSelected: include);
                }
                final next = _document.copyWith(
                  bundle: _bundle.copyWith(lines: lines),
                );
                _commitDocument(next);
              }
            : null,
        onSetLineLength: hasLine
            ? () {
                _clearHighlightedConstraints();
                unawaited(_emitLengthCommand());
              }
            : null,
        onSetHorizontal: hasLine
            ? () {
                _clearHighlightedConstraints();
                unawaited(
                  _setAxisConstraint(
                    effectiveLineIndex,
                    RoomEditorConstraintType.horizontal,
                  ),
                );
              }
            : null,
        onSetVertical: hasLine
            ? () {
                _clearHighlightedConstraints();
                unawaited(
                  _setAxisConstraint(
                    effectiveLineIndex,
                    RoomEditorConstraintType.vertical,
                  ),
                );
              }
            : null,
        onJointAction: _canJoin
            ? () {
                _clearHighlightedConstraints();
                unawaited(_joinSelectedIntersectionLocally());
              }
            : null,
        onSetAngle: _canSetAngle
            ? () {
                _clearHighlightedConstraints();
                unawaited(_emitAngleCommand());
              }
            : null,
        onSetRightAngle: _canSetAngle
            ? () {
                _clearHighlightedConstraints();
                unawaited(
                  _emitAngleCommand(
                    fixedAngle: RoomEditorConstraintSolver.degreesToAngleValue(
                      90,
                    ),
                  ),
                );
              }
            : null,
        onSetParallel: _canSetParallel
            ? () {
                _clearHighlightedConstraints();
                unawaited(_setParallelConstraint());
              }
            : null,
        onToggleShowAllConstraints: () => setState(() {
          _clearHighlightedConstraintsState();
          _showAllConstraints = !_showAllConstraints;
        }),
      ),
      constraintsOnly: constraintsOnly,
      excludeConstraints: excludeConstraints,
    );
    return RoomEditorToolbar(actions: actions, vertical: vertical, wrap: wrap);
  }

  Widget _buildCanvas() => RoomEditorCanvas(
    document: _document,
    selectionMode: false,
    snapToGrid: _snapToGrid,
    showGrid: _showGrid,
    showAllConstraints: _showAllConstraints,
    documentConstraintState: _documentConstraintState,
    constraintVisualOffsets: _constraintVisualOffsets,
    highlightedConstraintKeys: _highlightedConstraintKeys,
    highlightedImplicitLengthLineIndices: _highlightedImplicitLengthLineIndices,
    fitRequestId: _fitCanvasRequest,
    selection: _selection,
    callbacks: RoomEditorCanvasCallbacks(
      onStartMoveIntersection: _beginGestureEdit,
      onMoveIntersection: (index, point) {
        final target = _snapToGrid
            ? RoomCanvasGeometry.snapPoint(point, _bundle.unitSystem)
            : point;
        _draggedIntersectionIndex = index;
        _draggedIntersectionTarget = target;
        _dragSolverScheduler.schedule(
          RoomEditorDragSolveRequest(
            currentDocument: _document,
            gestureBaseDocument: _gestureBaseDocument,
            movedIndex: index,
            movedTarget: target,
            emitDistanceThreshold: RoomCanvasGeometry.defaultGridSize(
              _bundle.unitSystem,
            ).toDouble(),
          ),
        );
      },
      onEndMoveIntersection: () async {
        await _commitGestureEdit();
      },
      onStartMoveLine: _beginGestureEdit,
      onMoveLine: (index, worldDelta) {
        final gridSize = RoomCanvasGeometry.defaultGridSize(_bundle.unitSystem);
        final delta = _snapToGrid
            ? Offset(
                ((worldDelta.dx / gridSize).round() * gridSize).toDouble(),
                ((worldDelta.dy / gridSize).round() * gridSize).toDouble(),
              )
            : worldDelta;
        _moveLineLocally(index, delta);
      },
      onEndMoveLine: () async {
        await _commitGestureEdit();
      },
      onStartMoveOpening: _beginGestureEdit,
      onMoveOpening: _moveOpeningLocally,
      onEndMoveOpening: () async {
        await _commitGestureEdit();
      },
      onTapIntersection: (index) async {
        _clearHighlightedConstraints();
        final next = Set<int>.from(_selectedIntersectionIndices);
        if (!next.add(index)) {
          next.remove(index);
        }
        _setSelection(RoomEditorSelection(selectedIntersectionIndices: next));
      },
      onTapOpening: (index) async {
        _clearHighlightedConstraints();
        _setSelection(RoomEditorSelection(selectedOpeningIndex: index));
      },
      onTapLine: (index) async {
        _clearHighlightedConstraints();
        final next = Set<int>.from(_selectedLineIndices);
        if (!next.add(index)) {
          next.remove(index);
        }
        _setSelection(RoomEditorSelection(selectedLineIndices: next));
      },
      onTapCeiling: () async {
        _clearHighlightedConstraints();
        _setSelection(const RoomEditorSelection.empty());
      },
      onTapConstraint: (key) async {
        if (!_highlightedConstraintKeys.contains(key)) {
          _clearHighlightedConstraints();
        }
        _selectConstraint(key);
      },
      onMoveConstraint: (key, worldOffset) {
        _clearHighlightedConstraints();
        _moveConstraintVisual(key, worldOffset);
      },
      onDeleteConstraint: (key) async {
        _clearHighlightedConstraints();
        await _confirmDeleteConstraint(key);
      },
    ),
  );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.delete): _handleDeleteShortcut,
      const SingleActivator(LogicalKeyboardKey.backspace):
          _handleDeleteShortcut,
    },
    child: Focus(
      autofocus: true,
      focusNode: _focusNode,
      child: LayoutBuilder(
        builder: (context, constraints) => RoomEditorShell(
          landscape: widget.landscape,
          editorOnly: widget.editorOnly,
          primaryTools: _buildToolbar(
            vertical: widget.landscape,
            wrap: !widget.landscape && constraints.maxWidth < 520,
            excludeConstraints: widget.landscape,
          ),
          canvas: _buildCanvas(),
          constraintTools: widget.landscape && widget.showConstraintsInLandscape
              ? _buildToolbar(
                  vertical: true,
                  wrap: false,
                  constraintsOnly: true,
                )
              : null,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _focusNode.dispose();
    _dragSolverScheduler.dispose();
    super.dispose();
  }
}
