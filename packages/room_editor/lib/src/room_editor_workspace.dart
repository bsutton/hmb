import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'editor_toolbar.dart';
import 'editor_toolbar_models.dart';
import 'room_canvas.dart';
import 'room_canvas_geometry.dart';
import 'room_canvas_models.dart';
import 'room_constraint_solver.dart';
import 'room_editor_dialogs.dart';
import 'room_editor_shell.dart';

class RoomEditorWorkspace extends StatefulWidget {
  final RoomEditorDocument document;
  final bool landscape;
  final bool editorOnly;
  final bool showConstraintsInLandscape;
  final ValueChanged<RoomEditorDocument> onDocumentCommitted;
  final ValueChanged<RoomEditorCommand>? onCommand;
  final RoomEditorSelectionController? selectionController;

  const RoomEditorWorkspace({
    super.key,
    required this.document,
    required this.onDocumentCommitted,
    this.onCommand,
    this.landscape = false,
    this.editorOnly = false,
    this.showConstraintsInLandscape = true,
    this.selectionController,
  });

  @override
  State<RoomEditorWorkspace> createState() => _RoomEditorWorkspaceState();
}

class _RoomEditorWorkspaceState extends State<RoomEditorWorkspace> {
  late RoomEditorDocument _document;
  var _selectionMode = false;
  var _snapToGrid = true;
  var _showGrid = true;
  var _fitCanvasRequest = 0;
  RoomEditorSelection _selection = const RoomEditorSelection();
  RoomEditorDocument? _gestureBaseDocument;

  RoomEditorBundle get _bundle => _document.bundle;
  RoomEditorSelectionController? get _externalSelectionController =>
      widget.selectionController;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _selection = _normalizeSelection(
      _externalSelectionController?.value ?? const RoomEditorSelection(),
      _document,
    );
  }

  @override
  void didUpdateWidget(covariant RoomEditorWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _document = widget.document;
      _selection = _normalizeSelection(_selection, _document);
    }
    if (oldWidget.selectionController != widget.selectionController) {
      _selection = _normalizeSelection(
        _externalSelectionController?.value ?? _selection,
        _document,
      );
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
  );

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
  }) => RoomEditorConstraintSolver.solve(
    lines: document.bundle.lines,
    constraints: document.constraints,
    pinnedVertexIndex: pinnedVertexIndex,
    pinnedVertexTarget: pinnedVertexTarget,
  );

  void _replaceDocument(RoomEditorDocument document) {
    setState(() {
      _document = document;
      _selection = _normalizeSelection(_selection, document);
    });
    _externalSelectionController?.value = _selection;
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
    _replaceDocument(solved);
    widget.onDocumentCommitted(solved);
    return true;
  }

  void _beginGestureEdit() {
    _gestureBaseDocument ??= _document;
  }

  void _commitGestureEdit() {
    _gestureBaseDocument = null;
    widget.onDocumentCommitted(_document);
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

  Future<void> _toggleAxisConstraint(
    int index,
    RoomEditorConstraintType axisType,
  ) async {
    final line = _bundle.lines[index];
    final existing = _document.constraints.any(
      (constraint) =>
          constraint.lineId == line.id && constraint.type == axisType,
    );
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
    if (existing) {
      await _trySolveAndCommit(document);
      return;
    }

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
    final lineIndex = _selection.selectedLineIndex;
    if (lineIndex == null) {
      return;
    }
    final length = await showRoomEditorLengthDialog(
      context: context,
      unitSystem: _bundle.unitSystem,
      initialValue: _bundle.lines[lineIndex].length,
    );
    if (length == null || !mounted || widget.onCommand == null) {
      return;
    }
    widget.onCommand!(
      RoomEditorCommand(
        type: RoomEditorCommandType.setLineLength,
        document: _document,
        lineIndex: lineIndex,
        intValue: length,
      ),
    );
  }

  void _emitRemoveLengthCommand() {
    if (_selection.selectedLineIndex == null || widget.onCommand == null) {
      return;
    }
    widget.onCommand!(
      RoomEditorCommand(
        type: RoomEditorCommandType.removeLineLength,
        document: _document,
        lineIndex: _selection.selectedLineIndex,
      ),
    );
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
    RoomEditorConstraint? angleConstraint;
    for (final constraint in _document.constraints) {
      if (constraint.lineId == line.id &&
          constraint.type == RoomEditorConstraintType.jointAngle) {
        angleConstraint = constraint;
        break;
      }
    }
    if (angleConstraint != null) {
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
      initialValue: RoomEditorConstraintSolver.currentAngleValue(
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
    final hasLine =
        _selection.selectedLineIndex != null &&
        _selection.selectedLineIndex! < _bundle.lines.length;
    final hasIntersection =
        _selection.selectedIntersectionIndex != null &&
        _selection.selectedIntersectionIndex! < _bundle.lines.length;
    final hasOpening =
        _selection.selectedOpeningIndex != null &&
        _selection.selectedOpeningIndex! < _bundle.openings.length;
    final selectedLine = hasLine
        ? _bundle.lines[_selection.selectedLineIndex!]
        : null;
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
        isSelectedLinePlaster: selectedLine?.plasterSelected ?? false,
        isSelectedOpeningDoor:
            selectedOpening?.type == RoomEditorOpeningType.door,
      ),
      callbacks: RoomEditorToolbarCallbacks(
        onToggleSelectionMode: () =>
            setState(() => _selectionMode = !_selectionMode),
        onUndo: null,
        onRedo: null,
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
                final line = lines[_selection.selectedLineIndex!];
                lines[_selection.selectedLineIndex!] = line.copyWith(
                  plasterSelected: !line.plasterSelected,
                );
                final next = _document.copyWith(
                  bundle: _bundle.copyWith(lines: lines),
                );
                _replaceDocument(next);
                widget.onDocumentCommitted(next);
              }
            : null,
        onToggleLineLength: hasLine
            ? () => hasLineLengthConstraint
                  ? _emitRemoveLengthCommand()
                  : unawaited(_emitLengthCommand())
            : null,
        onToggleHorizontal: hasLine
            ? () => unawaited(
                _toggleAxisConstraint(
                  _selection.selectedLineIndex!,
                  RoomEditorConstraintType.horizontal,
                ),
              )
            : null,
        onToggleVertical: hasLine
            ? () => unawaited(
                _toggleAxisConstraint(
                  _selection.selectedLineIndex!,
                  RoomEditorConstraintType.vertical,
                ),
              )
            : null,
        onJointAction: hasIntersection
            ? () => unawaited(_emitJointCommand())
            : null,
        onToggleAngle: hasIntersection
            ? () => unawaited(_emitAngleCommand())
            : null,
      ),
      constraintsOnly: constraintsOnly,
      excludeConstraints: excludeConstraints,
    );
    return PlasterboardEditorToolbar(
      actions: actions,
      vertical: vertical,
      wrap: wrap,
    );
  }

  Widget _buildCanvas() => RoomEditorCanvas(
    bundle: _bundle,
    selectionMode: _selectionMode,
    snapToGrid: _snapToGrid,
    showGrid: _showGrid,
    fitRequestId: _fitCanvasRequest,
    selection: _selection,
    callbacks: RoomEditorCanvasCallbacks(
      onStartMoveIntersection: _beginGestureEdit,
      onMoveIntersection: (index, point) {
        final base = _gestureBaseDocument ?? _document;
        final target = _snapToGrid
            ? RoomCanvasGeometry.snapPoint(point, _bundle.unitSystem)
            : point;
        final lines = List<RoomEditorLine>.from(base.bundle.lines);
        lines[index] = lines[index].copyWith(
          startX: target.x,
          startY: target.y,
        );
        final result = _solveDocument(
          base.copyWith(bundle: base.bundle.copyWith(lines: lines)),
          pinnedVertexIndex: index,
          pinnedVertexTarget: target,
        );
        if (result.converged) {
          _replaceDocument(
            base.copyWith(bundle: base.bundle.copyWith(lines: result.lines)),
          );
        }
      },
      onEndMoveIntersection: () async {
        _commitGestureEdit();
      },
      onStartMoveOpening: _beginGestureEdit,
      onMoveOpening: _moveOpeningLocally,
      onEndMoveOpening: () async {
        _commitGestureEdit();
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
          _replaceDocument(next);
          widget.onDocumentCommitted(next);
        }
      },
      onTapCeiling: () async {
        if (!_selectionMode) {
          return;
        }
        final next = _document.copyWith(
          bundle: _bundle.copyWith(plasterCeiling: !_bundle.plasterCeiling),
        );
        _replaceDocument(next);
        widget.onDocumentCommitted(next);
      },
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
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
          ? _buildToolbar(vertical: true, wrap: false, constraintsOnly: true)
          : null,
    ),
  );
}
