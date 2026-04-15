import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../room_editor.dart';
import 'room_editor_drag_solver.dart';
import 'room_editor_solver_scheduler.dart';

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
  });

  @override
  State<RoomEditorWorkspace> createState() => _RoomEditorWorkspaceState();
}

class _RoomEditorWorkspaceState extends State<RoomEditorWorkspace> {
  late RoomEditorDocument _document;
  var _selectionMode = false;
  var _snapToGrid = true;
  var _showGrid = true;
  var _showAllConstraints = false;
  var _fitCanvasRequest = 0;
  var _selection = const RoomEditorSelection();
  RoomEditorDocument? _gestureBaseDocument;
  var _localHistory = const RoomEditorHistory();
  late final RoomEditorSolverScheduler _dragSolverScheduler;
  late final FocusNode _focusNode;
  int? _draggedIntersectionIndex;
  RoomEditorIntPoint? _draggedIntersectionTarget;
  var _rigidDragNotificationShownForGesture = false;
  Map<RoomEditorConstraintKey, Offset> _constraintVisualOffsets = {};

  RoomEditorBundle get _bundle => _document.bundle;
  RoomEditorSelectionController? get _externalSelectionController =>
      widget.selectionController;
  RoomEditorHistoryController? get _historyController =>
      widget.historyController;
  RoomEditorHistory get _history => _historyController?.value ?? _localHistory;
  bool get _canUndo => _history.undoStack.isNotEmpty;
  bool get _canRedo => _history.redoStack.isNotEmpty;
  int? get _selectedWallIndex {
    final lineIndex = _selection.selectedLineIndex;
    if (lineIndex != null &&
        lineIndex >= 0 &&
        lineIndex < _bundle.lines.length) {
      return lineIndex;
    }
    final intersectionIndex = _selection.selectedIntersectionIndex;
    if (intersectionIndex != null &&
        intersectionIndex >= 0 &&
        intersectionIndex < _bundle.lines.length) {
      return intersectionIndex;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _focusNode = FocusNode(debugLabel: 'RoomEditorWorkspace');
    _selection = _normalizeSelection(
      _externalSelectionController?.value ?? const RoomEditorSelection(),
      _document,
    );
    _constraintVisualOffsets = _pruneConstraintVisualOffsets(
      _constraintVisualOffsets,
      _document,
    );
    _dragSolverScheduler = createRoomEditorSolverScheduler(
      onEmit: (result) {
        if (!mounted || result.solvedDocument == null) {
          return;
        }
        _maybeShowRigidDragNotification(result);
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

  int? _lineIndexForConstraintKey(RoomEditorConstraintKey key) {
    final index = _bundle.lines.indexWhere((line) => line.id == key.lineId);
    return index >= 0 ? index : null;
  }

  void _selectConstraint(RoomEditorConstraintKey key) {
    final lineIndex = _lineIndexForConstraintKey(key);
    if (lineIndex == null) {
      return;
    }
    _setSelection(
      RoomEditorSelection(
        selectedLineIndex: key.type == RoomEditorConstraintType.jointAngle
            ? null
            : lineIndex,
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
    selectedLineIndex:
        selection.selectedLineIndex != null &&
            selection.selectedLineIndex! >= 0 &&
            selection.selectedLineIndex! < document.bundle.lines.length
        ? selection.selectedLineIndex
        : null,
    selectedIntersectionIndex:
        selection.selectedIntersectionIndex != null &&
            selection.selectedIntersectionIndex! >= 0 &&
            selection.selectedIntersectionIndex! < document.bundle.lines.length
        ? selection.selectedIntersectionIndex
        : null,
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
  }) async {
    final result = _solveDocument(
      document,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
    );
    if (!result.converged) {
      return false;
    }
    final solved = document.copyWith(
      bundle: document.bundle.copyWith(lines: result.lines),
    );
    _commitDocument(solved);
    return true;
  }

  void _beginGestureEdit() {
    _gestureBaseDocument ??= _document;
    _draggedIntersectionIndex = null;
    _draggedIntersectionTarget = null;
    _rigidDragNotificationShownForGesture = false;
  }

  Future<void> _commitGestureEdit() async {
    final baseDocument = _gestureBaseDocument;
    _gestureBaseDocument = null;
    _dragSolverScheduler.cancel();
    final draggedIntersectionIndex = _draggedIntersectionIndex;
    final draggedIntersectionTarget = _draggedIntersectionTarget;
    _draggedIntersectionIndex = null;
    _draggedIntersectionTarget = null;
    if (draggedIntersectionIndex != null && draggedIntersectionTarget != null) {
      final finalResult = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: _document,
          gestureBaseDocument: baseDocument,
          movedIndex: draggedIntersectionIndex,
          movedTarget: draggedIntersectionTarget,
          emitDistanceThreshold: RoomCanvasGeometry.defaultGridSize(
            _bundle.unitSystem,
          ).toDouble(),
        ),
      );
      if (finalResult.solvedDocument != null) {
        _maybeShowRigidDragNotification(finalResult);
        _replaceDocument(finalResult.solvedDocument!);
      }
    }
    debugPrint(
      '[room_drag] commit document=${_formatLines(_document.bundle.lines)}',
    );
    if (baseDocument != null) {
      _commitDocument(_document, previousDocument: baseDocument);
      return;
    }
    widget.onDocumentCommitted(_document);
  }

  void _maybeShowRigidDragNotification(RoomEditorDragSolveResult result) {
    if (_rigidDragNotificationShownForGesture || !result.rigidConstraintClamp) {
      return;
    }
    _rigidDragNotificationShownForGesture = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'This room is rigid. Remove one or more constraints to modify '
            'the room.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
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
        ) ||
        await _trySolveAndCommit(
          endPinnedDocument,
          pinnedVertexIndex: nextIndex,
          pinnedVertexTarget: lineEnd,
        ) ||
        await _trySolveAndCommit(document);
    if (solved && mounted) {
      _selectConstraint(key);
    }
  }

  void _emitCommand(RoomEditorCommandType type) {
    if (widget.onCommand == null) {
      return;
    }
    widget.onCommand!(
      RoomEditorCommand(
        type: type,
        document: _document,
        lineIndex: _selection.selectedLineIndex,
        openingIndex: _selection.selectedOpeningIndex,
        intersectionIndex: _selection.selectedIntersectionIndex,
      ),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Constraint'),
        content: const Text('Delete the selected constraint?'),
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
    );
    if (opening == null || !mounted || widget.onCommand == null) {
      return;
    }
    widget.onCommand!(
      RoomEditorCommand(
        type: RoomEditorCommandType.addOpening,
        document: _document,
        lineIndex: lineIndex,
        openingDraft: opening,
      ),
    );
  }

  Future<void> _emitEditOpeningCommand() async {
    final openingIndex = _selection.selectedOpeningIndex;
    if (openingIndex == null) {
      return;
    }
    final opening = _bundle.openings[openingIndex];
    final updated = await showRoomEditorOpeningDialog(
      context: context,
      unitSystem: _bundle.unitSystem,
      type: opening.type,
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
    if (updated == null || !mounted || widget.onCommand == null) {
      return;
    }
    widget.onCommand!(
      RoomEditorCommand(
        type: RoomEditorCommandType.editOpening,
        document: _document,
        openingIndex: openingIndex,
        openingDraft: updated,
      ),
    );
  }

  Future<void> _emitJointCommand() async {
    final intersectionIndex = _selection.selectedIntersectionIndex;
    if (intersectionIndex == null || widget.onCommand == null) {
      return;
    }
    final line = _bundle.lines[intersectionIndex];
    final hasAngleConstraint = _document.constraints.any(
      (constraint) =>
          constraint.lineId == line.id &&
          constraint.type == RoomEditorConstraintType.jointAngle,
    );
    final action = await showRoomEditorJointActionSheet(
      context: context,
      hasAngleConstraint: hasAngleConstraint,
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == 'join') {
      widget.onCommand!(
        RoomEditorCommand(
          type: RoomEditorCommandType.joinIntersection,
          document: _document,
          intersectionIndex: intersectionIndex,
        ),
      );
      return;
    }
    if (action == 'remove-angle') {
      widget.onCommand!(
        RoomEditorCommand(
          type: RoomEditorCommandType.removeAngle,
          document: _document,
          intersectionIndex: intersectionIndex,
        ),
      );
      return;
    }
    final angle = await showRoomEditorAngleDialog(
      context: context,
      initialValue: hasAngleConstraint
          ? _document.constraints
                    .firstWhere(
                      (constraint) =>
                          constraint.lineId == line.id &&
                          constraint.type ==
                              RoomEditorConstraintType.jointAngle,
                    )
                    .targetValue ??
                RoomEditorConstraintSolver.currentAngleValue(
                  _bundle.lines,
                  intersectionIndex,
                )
          : RoomEditorConstraintSolver.currentAngleValue(
              _bundle.lines,
              intersectionIndex,
            ),
    );
    if (angle == null || !mounted) {
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

  Future<void> _emitAngleCommand() async {
    final intersectionIndex = _selection.selectedIntersectionIndex;
    if (intersectionIndex == null || widget.onCommand == null) {
      return;
    }
    final line = _bundle.lines[intersectionIndex];
    final angleConstraint = _constraintForKey(
      RoomEditorConstraintKey(
        lineId: line.id,
        type: RoomEditorConstraintType.jointAngle,
      ),
    );
    final angle = await showRoomEditorAngleDialog(
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
    widget.onCommand!(
      RoomEditorCommand(
        type: RoomEditorCommandType.setAngle,
        document: _document,
        intersectionIndex: intersectionIndex,
        intValue: angle,
      ),
    );
  }

  Widget _buildToolbar({
    required bool vertical,
    required bool wrap,
    bool constraintsOnly = false,
    bool excludeConstraints = false,
  }) {
    final effectiveLineIndex = _selectedWallIndex;
    final hasLine = effectiveLineIndex != null;
    final hasIntersection =
        _selection.selectedIntersectionIndex != null &&
        _selection.selectedIntersectionIndex! < _bundle.lines.length;
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
    final selectedIntersectionLine = hasIntersection
        ? _bundle.lines[_selection.selectedIntersectionIndex!]
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
        selectionMode: _selectionMode,
        snapToGrid: _snapToGrid,
        showGrid: _showGrid,
        hasLine: hasLine,
        hasIntersection: hasIntersection,
        hasOpening: hasOpening,
        hasLineLengthConstraint: hasLineLengthConstraint,
        hasHorizontalConstraint: hasHorizontalConstraint,
        hasVerticalConstraint: hasVerticalConstraint,
        hasAngleConstraint: hasAngleConstraint,
        showAllConstraints: _showAllConstraints,
        isSelectedLinePlaster: selectedLine?.plasterSelected ?? false,
        isSelectedOpeningDoor:
            selectedOpening?.type == RoomEditorOpeningType.door,
      ),
      callbacks: RoomEditorToolbarCallbacks(
        onToggleSelectionMode: () =>
            setState(() => _selectionMode = !_selectionMode),
        onUndo: _canUndo ? _undoLocally : null,
        onRedo: _canRedo ? _redoLocally : null,
        onFit: () => setState(() => _fitCanvasRequest++),
        onToggleSnapToGrid: () => setState(() => _snapToGrid = !_snapToGrid),
        onToggleShowGrid: () => setState(() => _showGrid = !_showGrid),
        onDeselect: () => _setSelection(const RoomEditorSelection()),
        onSplit: hasLine
            ? () => _emitCommand(RoomEditorCommandType.splitLine)
            : null,
        onAddDoor: hasLine
            ? () => unawaited(_emitOpeningCommand(RoomEditorOpeningType.door))
            : null,
        onAddWindow: hasLine
            ? () => unawaited(_emitOpeningCommand(RoomEditorOpeningType.window))
            : null,
        onEditOpening: hasOpening
            ? () => unawaited(_emitEditOpeningCommand())
            : null,
        onDeleteOpening: hasOpening
            ? () => _emitCommand(RoomEditorCommandType.deleteOpening)
            : null,
        onToggleLinePlaster: hasLine
            ? () {
                final lines = List<RoomEditorLine>.from(_bundle.lines);
                final line = lines[effectiveLineIndex];
                lines[effectiveLineIndex] = line.copyWith(
                  plasterSelected: !line.plasterSelected,
                );
                final next = _document.copyWith(
                  bundle: _bundle.copyWith(lines: lines),
                );
                _commitDocument(next);
              }
            : null,
        onSetLineLength: hasLine ? () => unawaited(_emitLengthCommand()) : null,
        onSetHorizontal: hasLine
            ? () => unawaited(
                _setAxisConstraint(
                  effectiveLineIndex,
                  RoomEditorConstraintType.horizontal,
                ),
              )
            : null,
        onSetVertical: hasLine
            ? () => unawaited(
                _setAxisConstraint(
                  effectiveLineIndex,
                  RoomEditorConstraintType.vertical,
                ),
              )
            : null,
        onJointAction: hasIntersection
            ? () => unawaited(_emitJointCommand())
            : null,
        onSetAngle: hasIntersection
            ? () => unawaited(_emitAngleCommand())
            : null,
        onToggleShowAllConstraints: () =>
            setState(() => _showAllConstraints = !_showAllConstraints),
      ),
      constraintsOnly: constraintsOnly,
      excludeConstraints: excludeConstraints,
    );
    return RoomEditorToolbar(actions: actions, vertical: vertical, wrap: wrap);
  }

  Widget _buildCanvas() => RoomEditorCanvas(
    document: _document,
    selectionMode: _selectionMode,
    snapToGrid: _snapToGrid,
    showGrid: _showGrid,
    showAllConstraints: _showAllConstraints,
    constraintVisualOffsets: _constraintVisualOffsets,
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
      onStartMoveOpening: _beginGestureEdit,
      onMoveOpening: _moveOpeningLocally,
      onEndMoveOpening: () async {
        await _commitGestureEdit();
      },
      onTapIntersection: (index) async {
        _setSelection(RoomEditorSelection(selectedIntersectionIndex: index));
      },
      onTapOpening: (index) async {
        _setSelection(RoomEditorSelection(selectedOpeningIndex: index));
      },
      onTapLine: (index) async {
        _setSelection(RoomEditorSelection(selectedLineIndex: index));
        if (_selectionMode) {
          final lines = List<RoomEditorLine>.from(_bundle.lines);
          final line = lines[index];
          lines[index] = line.copyWith(plasterSelected: !line.plasterSelected);
          final next = _document.copyWith(
            bundle: _bundle.copyWith(lines: lines),
          );
          _commitDocument(next);
        }
      },
      onTapCeiling: () async {
        if (!_selectionMode) {
          return;
        }
        final next = _document.copyWith(
          bundle: _bundle.copyWith(plasterCeiling: !_bundle.plasterCeiling),
        );
        _commitDocument(next);
      },
      onTapConstraint: (key) async {
        _selectConstraint(key);
      },
      onMoveConstraint: _moveConstraintVisual,
      onDeleteConstraint: _confirmDeleteConstraint,
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
