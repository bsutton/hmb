import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../room_editor.dart';

class RoomEditorCanvas extends StatefulWidget {
  final RoomEditorDocument document;
  final bool selectionMode;
  final bool snapToGrid;
  final bool showGrid;
  final bool showAllConstraints;
  final Map<RoomEditorConstraintKey, Offset> constraintVisualOffsets;
  final Set<RoomEditorConstraintKey> highlightedConstraintKeys;
  final int fitRequestId;
  final RoomEditorSelection selection;
  final RoomEditorCanvasCallbacks callbacks;
  final double height;

  const RoomEditorCanvas({
    required this.document,
    required this.selectionMode,
    required this.snapToGrid,
    required this.showGrid,
    required this.showAllConstraints,
    required this.constraintVisualOffsets,
    required this.highlightedConstraintKeys,
    required this.fitRequestId,
    required this.selection,
    required this.callbacks,
    super.key,
    this.height = 360,
  });

  @override
  State<RoomEditorCanvas> createState() => _RoomEditorCanvasState();
}

enum _RoomTapTargetType { intersection, line }

class _RoomTapTarget {
  final _RoomTapTargetType type;
  final int index;
  final double distance;

  const _RoomTapTarget({
    required this.type,
    required this.index,
    required this.distance,
  });
}

class _RoomEditorCanvasState extends State<RoomEditorCanvas> {
  RoomEditorBundle get _bundle => widget.document.bundle;

  int? _dragIndex;
  int? _dragLineIndex;
  int? _dragOpeningIndex;
  RoomEditorConstraintKey? _dragConstraintKey;
  var _dragOpeningAnchorOffset = 0;
  int? _pendingDragIndex;
  int? _pendingDragLineIndex;
  int? _pendingDragOpeningIndex;
  RoomEditorConstraintKey? _pendingDragConstraintKey;
  var _pendingDragOpeningAnchorOffset = 0;
  int? _gesturePointer;
  Offset? _gestureStartPosition;
  int? _secondaryPanPointer;
  Offset? _secondaryPanPosition;
  var _activePointerCount = 0;
  _CanvasTransform? _dragTransform;
  _CanvasWorldBounds? _dragViewportBounds;
  final _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(BrowserContextMenu.disableContextMenu());
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      unawaited(BrowserContextMenu.enableContextMenu());
    }
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RoomEditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitRequestId != widget.fitRequestId) {
      _transformationController.value = Matrix4.identity();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event, Size size) {
    if (event is! PointerScrollEvent) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      final localPosition = scrollEvent.localPosition;
      if (localPosition.dx < 0 ||
          localPosition.dy < 0 ||
          localPosition.dx > size.width ||
          localPosition.dy > size.height) {
        return;
      }

      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      final scaleDelta = exp(-scrollEvent.scrollDelta.dy / 240);
      final nextScale = (currentScale * scaleDelta).clamp(0.5, 4.0);
      final appliedDelta = nextScale / currentScale;
      if (appliedDelta == 1) {
        return;
      }

      final zoomMatrix = Matrix4.identity()
        ..translateByDouble(localPosition.dx, localPosition.dy, 0, 1)
        ..scaleByDouble(appliedDelta, appliedDelta, 1, 1)
        ..translateByDouble(-localPosition.dx, -localPosition.dy, 0, 1);
      _transformationController.value = zoomMatrix.multiplied(
        _transformationController.value,
      );
    });
  }

  bool get _isDraggingGeometry =>
      _dragIndex != null ||
      _dragLineIndex != null ||
      _dragOpeningIndex != null ||
      _dragConstraintKey != null;

  void _cancelGeometryDrag() {
    final draggingOpening = _dragOpeningIndex != null;
    final draggingIntersection = _dragIndex != null;
    final draggingLine = _dragLineIndex != null;
    final draggingConstraint = _dragConstraintKey != null;

    _dragOpeningIndex = null;
    _dragOpeningAnchorOffset = 0;
    _dragIndex = null;
    _dragLineIndex = null;
    _dragConstraintKey = null;
    _clearPendingGesture();

    if (draggingOpening ||
        draggingIntersection ||
        draggingLine ||
        draggingConstraint) {
      setState(() {});
      if (draggingOpening) {
        unawaited(widget.callbacks.onEndMoveOpening());
      } else if (draggingIntersection) {
        unawaited(widget.callbacks.onEndMoveIntersection());
      } else if (draggingLine) {
        unawaited(widget.callbacks.onEndMoveLine());
      }
    }
  }

  void _clearPendingGesture() {
    _pendingDragIndex = null;
    _pendingDragLineIndex = null;
    _pendingDragOpeningIndex = null;
    _pendingDragConstraintKey = null;
    _pendingDragOpeningAnchorOffset = 0;
    _gesturePointer = null;
    _gestureStartPosition = null;
    _dragTransform = null;
    _dragViewportBounds = null;
  }

  bool _isSecondaryMousePanEvent(PointerEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      (event.buttons & kSecondaryMouseButton) != 0;

  void _panCanvas(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    final panMatrix = Matrix4.identity()
      ..translateByDouble(delta.dx, delta.dy, 0, 1);
    _transformationController.value = panMatrix.multiplied(
      _transformationController.value,
    );
  }

  Offset _toCanvasSpace(Offset viewportPosition) {
    final inverse = Matrix4.inverted(_transformationController.value);
    return MatrixUtils.transformPoint(inverse, viewportPosition);
  }

  List<_ConstraintVisual> _constraintVisuals(_CanvasTransform transform) =>
      buildConstraintVisuals(
        document: widget.document,
        selection: widget.selection,
        showAllConstraints: widget.showAllConstraints,
        customOffsets: widget.constraintVisualOffsets,
        highlightedKeys: widget.highlightedConstraintKeys,
        transform: transform,
      );

  _ConstraintVisual? _hitConstraint(
    Offset canvasPosition,
    _CanvasTransform transform,
  ) {
    for (final visual in _constraintVisuals(transform).reversed) {
      if (visual.contains(canvasPosition)) {
        return visual;
      }
    }
    return null;
  }

  _ConstraintVisual? _hitLineLengthConstraintLabel(
    Offset canvasPosition,
    _CanvasTransform transform,
  ) {
    final visuals = _constraintVisuals(transform);
    for (final visual in visuals.reversed) {
      if (visual.key.type == RoomEditorConstraintType.lineLength &&
          visual.hitBox.contains(canvasPosition)) {
        return visual;
      }
    }
    return null;
  }

  int? _hitPlainLineLengthLabel(
    Offset canvasPosition,
    _CanvasTransform transform,
  ) {
    final lines = _bundle.lines;
    if (lines.isEmpty) {
      return null;
    }
    final visibleConstraintKeys = {
      for (final visual in _constraintVisuals(transform)) visual.key,
    };
    final polygonDirection = _polygonDirection(lines);
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final hasVisibleLengthConstraint = visibleConstraintKeys.contains(
        RoomEditorConstraintKey(
          lineId: line.id,
          type: RoomEditorConstraintType.lineLength,
        ),
      );
      if (hasVisibleLengthConstraint) {
        continue;
      }
      final start = transform.toCanvasPoint(line.startX, line.startY);
      final endPoint = RoomCanvasGeometry.lineEnd(lines, i);
      final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final segmentLength = sqrt(dx * dx + dy * dy);
      final normal = segmentLength == 0
          ? const Offset(0, -1)
          : Offset(-dy / segmentLength, dx / segmentLength);
      final outsideNormal = polygonDirection >= 0 ? -normal : normal;
      final labelText = RoomCanvasGeometry.formatDisplayLength(
        line.length,
        _bundle.unitSystem,
      );
      final labelPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelOffset =
          mid +
          outsideNormal * 40 -
          Offset(labelPainter.width / 2, labelPainter.height / 2);
      final labelRect = Rect.fromLTWH(
        labelOffset.dx - 4,
        labelOffset.dy - 2,
        labelPainter.width + 8,
        labelPainter.height + 4,
      );
      if (labelRect.contains(canvasPosition)) {
        return i;
      }
    }
    return null;
  }

  bool _preferGeometrySelection(
    Offset canvasPosition,
    _CanvasTransform transform,
  ) {
    if (transform.hitOpening(_bundle.openings, canvasPosition) != null) {
      return true;
    }
    if (transform.hitIntersection(canvasPosition) != null) {
      return true;
    }
    final lineCandidates = transform.hitLineCandidates(canvasPosition);
    if (lineCandidates.isEmpty) {
      return false;
    }
    return lineCandidates.first.$2 <= 12;
  }

  void _handlePointerDown(PointerDownEvent event, _CanvasTransform transform) {
    _activePointerCount++;
    if (_isSecondaryMousePanEvent(event)) {
      _cancelGeometryDrag();
      _secondaryPanPointer = event.pointer;
      _secondaryPanPosition = event.localPosition;
      return;
    }
    if (_activePointerCount > 1) {
      _cancelGeometryDrag();
      return;
    }
    if (_isDraggingGeometry) {
      _clearPendingGesture();
      return;
    }

    _gesturePointer = event.pointer;
    final canvasPosition = _toCanvasSpace(event.localPosition);
    _gestureStartPosition = canvasPosition;
    final constraintVisual = _preferGeometrySelection(canvasPosition, transform)
        ? null
        : _hitConstraint(canvasPosition, transform);
    if (constraintVisual != null) {
      _dragTransform = transform;
      _pendingDragConstraintKey = constraintVisual.key;
      _pendingDragOpeningIndex = null;
      _pendingDragIndex = null;
      _pendingDragLineIndex = null;
      return;
    }
    _pendingDragOpeningIndex = transform.hitOpening(
      _bundle.openings,
      canvasPosition,
    );
    if (_pendingDragOpeningIndex != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= _CanvasWorldBounds.fromDocument(
        document: widget.document,
        selection: widget.selection,
        showAllConstraints: widget.showAllConstraints,
        customOffsets: widget.constraintVisualOffsets,
        size: transform.size,
      );
      _pendingDragOpeningAnchorOffset = transform.openingDragAnchorOffset(
        _bundle.openings,
        canvasPosition,
        _pendingDragOpeningIndex!,
      );
      _pendingDragIndex = null;
      _pendingDragLineIndex = null;
      return;
    }

    _pendingDragIndex = transform.hitIntersection(canvasPosition);
    if (_pendingDragIndex != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= _CanvasWorldBounds.fromDocument(
        document: widget.document,
        selection: widget.selection,
        showAllConstraints: widget.showAllConstraints,
        customOffsets: widget.constraintVisualOffsets,
        size: transform.size,
      );
      _pendingDragLineIndex = null;
      return;
    }
    final lineCandidates = transform.hitLineCandidates(canvasPosition);
    _pendingDragLineIndex = lineCandidates.isEmpty
        ? null
        : lineCandidates.first.$1;
    if (_pendingDragLineIndex != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= _CanvasWorldBounds.fromDocument(
        document: widget.document,
        selection: widget.selection,
        showAllConstraints: widget.showAllConstraints,
        customOffsets: widget.constraintVisualOffsets,
        size: transform.size,
      );
    }
  }

  void _handlePointerMove(PointerMoveEvent event, _CanvasTransform transform) {
    if (_gesturePointer == event.pointer && event.buttons == 0) {
      _handlePointerEnd(event.pointer);
      return;
    }

    if (_secondaryPanPointer == event.pointer &&
        _isSecondaryMousePanEvent(event)) {
      final previous = _secondaryPanPosition;
      if (previous != null) {
        _panCanvas(event.localPosition - previous);
      }
      _secondaryPanPosition = event.localPosition;
      return;
    }

    if (_gesturePointer != event.pointer || _activePointerCount != 1) {
      return;
    }

    final dragTransform = _dragTransform ?? transform;
    final canvasPosition = _toCanvasSpace(event.localPosition);
    if (_dragConstraintKey != null) {
      final visual = _hitConstraint(canvasPosition, dragTransform);
      final activeVisual = visual?.key == _dragConstraintKey
          ? visual
          : _constraintVisuals(
              dragTransform,
            ).firstWhere((candidate) => candidate.key == _dragConstraintKey);
      widget.callbacks.onMoveConstraint(
        _dragConstraintKey!,
        activeVisual!.offsetForDrag(canvasPosition, dragTransform),
      );
      return;
    }
    if (_dragOpeningIndex != null) {
      widget.callbacks.onMoveOpening(
        _dragOpeningIndex!,
        dragTransform.toWorld(canvasPosition),
        _dragOpeningAnchorOffset,
      );
      return;
    }
    if (_dragLineIndex != null) {
      final start = _gestureStartPosition;
      if (start == null) {
        return;
      }
      final worldDelta =
          dragTransform.toWorldOffset(canvasPosition) -
          dragTransform.toWorldOffset(start);
      widget.callbacks.onMoveLine(_dragLineIndex!, worldDelta);
      return;
    }
    if (_dragIndex != null) {
      widget.callbacks.onMoveIntersection(
        _dragIndex!,
        dragTransform.toWorld(canvasPosition),
      );
      return;
    }

    final start = _gestureStartPosition;
    if (start == null || (canvasPosition - start).distance <= 6) {
      return;
    }

    if (_pendingDragOpeningIndex != null) {
      _dragOpeningIndex = _pendingDragOpeningIndex;
      _dragOpeningAnchorOffset = _pendingDragOpeningAnchorOffset;
      widget.callbacks.onStartMoveOpening();
      setState(() {});
      widget.callbacks.onMoveOpening(
        _dragOpeningIndex!,
        dragTransform.toWorld(canvasPosition),
        _dragOpeningAnchorOffset,
      );
      return;
    }

    if (_pendingDragConstraintKey != null) {
      _dragConstraintKey = _pendingDragConstraintKey;
      setState(() {});
      final visual = _constraintVisuals(
        dragTransform,
      ).firstWhere((candidate) => candidate.key == _dragConstraintKey);
      widget.callbacks.onMoveConstraint(
        _dragConstraintKey!,
        visual.offsetForDrag(canvasPosition, dragTransform),
      );
      return;
    }

    if (_pendingDragLineIndex != null) {
      _dragLineIndex = _pendingDragLineIndex;
      widget.callbacks.onStartMoveLine();
      setState(() {});
      final worldDelta =
          dragTransform.toWorldOffset(canvasPosition) -
          dragTransform.toWorldOffset(start);
      widget.callbacks.onMoveLine(_dragLineIndex!, worldDelta);
      return;
    }

    if (_pendingDragIndex != null) {
      _dragIndex = _pendingDragIndex;
      widget.callbacks.onStartMoveIntersection();
      setState(() {});
      widget.callbacks.onMoveIntersection(
        _dragIndex!,
        dragTransform.toWorld(canvasPosition),
      );
    }
  }

  void _handlePointerEnd(int pointer) {
    if (_activePointerCount > 0) {
      _activePointerCount--;
    }
    if (_secondaryPanPointer == pointer) {
      _secondaryPanPointer = null;
      _secondaryPanPosition = null;
    }
    if (_gesturePointer != pointer) {
      return;
    }

    final draggingOpening = _dragOpeningIndex != null;
    final draggingIntersection = _dragIndex != null;
    final draggingLine = _dragLineIndex != null;
    final draggingConstraint = _dragConstraintKey != null;

    _dragOpeningIndex = null;
    _dragOpeningAnchorOffset = 0;
    _dragIndex = null;
    _dragLineIndex = null;
    _dragConstraintKey = null;
    _clearPendingGesture();

    if (draggingOpening ||
        draggingIntersection ||
        draggingLine ||
        draggingConstraint) {
      setState(() {});
      if (draggingOpening) {
        unawaited(widget.callbacks.onEndMoveOpening());
      } else if (draggingIntersection) {
        unawaited(widget.callbacks.onEndMoveIntersection());
      } else if (draggingLine) {
        unawaited(widget.callbacks.onEndMoveLine());
      }
    }
  }

  Future<void> _handleTapSelection(
    BuildContext context,
    Offset localPosition,
    _CanvasTransform transform,
  ) async {
    final lineLengthConstraintVisual = _hitLineLengthConstraintLabel(
      localPosition,
      transform,
    );
    if (lineLengthConstraintVisual != null) {
      await widget.callbacks.onTapConstraint(lineLengthConstraintVisual.key);
      return;
    }

    final plainLineLengthLabelIndex = _hitPlainLineLengthLabel(
      localPosition,
      transform,
    );
    if (plainLineLengthLabelIndex != null) {
      await widget.callbacks.onTapLine(plainLineLengthLabelIndex);
      return;
    }

    final constraintVisual = _preferGeometrySelection(localPosition, transform)
        ? null
        : _hitConstraint(localPosition, transform);
    if (constraintVisual != null) {
      await widget.callbacks.onTapConstraint(constraintVisual.key);
      return;
    }

    final openingIndex = transform.hitOpening(_bundle.openings, localPosition);
    if (openingIndex != null) {
      await widget.callbacks.onTapOpening(openingIndex);
      return;
    }

    final candidates =
        <_RoomTapTarget>[
          ...transform
              .hitIntersectionCandidates(localPosition)
              .map(
                (candidate) => _RoomTapTarget(
                  type: _RoomTapTargetType.intersection,
                  index: candidate.$1,
                  distance: candidate.$2,
                ),
              ),
          ...transform
              .hitLineCandidates(localPosition)
              .map(
                (candidate) => _RoomTapTarget(
                  type: _RoomTapTargetType.line,
                  index: candidate.$1,
                  distance: candidate.$2,
                ),
              ),
        ]..sort((left, right) {
          final distanceCompare = left.distance.compareTo(right.distance);
          if (distanceCompare != 0) {
            return distanceCompare;
          }
          if (left.type != right.type) {
            return left.type == _RoomTapTargetType.line ? -1 : 1;
          }
          return left.index.compareTo(right.index);
        });

    final uniqueCandidates = <_RoomTapTarget>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      final key = '${candidate.type.name}:${candidate.index}';
      if (seen.add(key)) {
        uniqueCandidates.add(candidate);
      }
    }

    if (uniqueCandidates.isEmpty) {
      await widget.callbacks.onTapCeiling();
      return;
    }

    if (uniqueCandidates.length == 1) {
      final candidate = uniqueCandidates.first;
      if (candidate.type == _RoomTapTargetType.intersection) {
        await widget.callbacks.onTapIntersection(candidate.index);
      } else {
        await widget.callbacks.onTapLine(candidate.index);
      }
      return;
    }

    final selected = await showModalBottomSheet<_RoomTapTarget>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final candidate in uniqueCandidates)
              ListTile(
                title: Text(
                  candidate.type == _RoomTapTargetType.line
                      ? 'Select W${candidate.index + 1}'
                      : 'Select vertex',
                ),
                onTap: () => Navigator.of(sheetContext).pop(candidate),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }
    if (selected.type == _RoomTapTargetType.intersection) {
      await widget.callbacks.onTapIntersection(selected.index);
    } else {
      await widget.callbacks.onTapLine(selected.index);
    }
  }

  Future<void> _handleLongPress(
    Offset viewportPosition,
    _CanvasTransform transform,
  ) async {
    final canvasPosition = _toCanvasSpace(viewportPosition);
    final constraintVisual = _preferGeometrySelection(canvasPosition, transform)
        ? null
        : _hitConstraint(canvasPosition, transform);
    if (constraintVisual == null) {
      return;
    }
    await widget.callbacks.onTapConstraint(constraintVisual.key);
    await widget.callbacks.onDeleteConstraint(constraintVisual.key);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final resolvedHeight =
          constraints.hasBoundedHeight && constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : widget.height;
      final size = Size(constraints.maxWidth, resolvedHeight);
      if (_bundle.lines.isEmpty) {
        return Container(
          height: size.height,
          width: size.width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'This room has no wall geometry yet. Add or recreate the room '
            'to start drawing.',
            textAlign: TextAlign.center,
          ),
        );
      }
      final viewportBounds =
          _dragViewportBounds ??
          _CanvasWorldBounds.fromDocument(
            document: widget.document,
            selection: widget.selection,
            showAllConstraints: widget.showAllConstraints,
            customOffsets: widget.constraintVisualOffsets,
            size: size,
          );
      final transform = _CanvasTransform(
        _bundle.lines,
        size,
        bounds: viewportBounds,
      );
      final constraintVisuals = _constraintVisuals(transform);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _handlePointerDown(event, transform),
        onPointerMove: (event) => _handlePointerMove(event, transform),
        onPointerUp: (event) => _handlePointerEnd(event.pointer),
        onPointerCancel: (event) => _handlePointerEnd(event.pointer),
        onPointerSignal: (event) => _handlePointerSignal(event, size),
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4,
          panEnabled: !_isDraggingGeometry,
          scaleEnabled: !_isDraggingGeometry,
          child: GestureDetector(
            onLongPressStart: (details) =>
                unawaited(_handleLongPress(details.localPosition, transform)),
            onTapUp: (details) => unawaited(
              _handleTapSelection(
                context,
                _toCanvasSpace(details.localPosition),
                transform,
              ),
            ),
            child: CustomPaint(
              size: size,
              painter: _RoomPainter(
                document: widget.document,
                transform: transform,
                selectionMode: widget.selectionMode,
                showGrid: widget.showGrid,
                constraintVisuals: constraintVisuals,
                highlightedConstraintKeys: widget.highlightedConstraintKeys,
                selectedLineIndices: widget.selection.selectedLineIndices,
                selectedIntersectionIndices:
                    widget.selection.selectedIntersectionIndices,
                selectedOpeningIndex: widget.selection.selectedOpeningIndex,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RoomPainter extends CustomPainter {
  final RoomEditorDocument document;
  final _CanvasTransform transform;
  final bool selectionMode;
  final bool showGrid;
  final List<_ConstraintVisual> constraintVisuals;
  final Set<RoomEditorConstraintKey> highlightedConstraintKeys;
  final Set<int> selectedLineIndices;
  final Set<int> selectedIntersectionIndices;
  final int? selectedOpeningIndex;

  RoomEditorBundle get bundle => document.bundle;

  const _RoomPainter({
    required this.document,
    required this.transform,
    required this.selectionMode,
    required this.showGrid,
    required this.constraintVisuals,
    required this.highlightedConstraintKeys,
    required this.selectedLineIndices,
    required this.selectedIntersectionIndices,
    required this.selectedOpeningIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final polygon = Path();
    final lines = bundle.lines;
    if (lines.isEmpty) {
      return;
    }
    final first = transform.toCanvasPoint(
      lines.first.startX,
      lines.first.startY,
    );
    polygon.moveTo(first.dx, first.dy);
    for (var i = 1; i < lines.length; i++) {
      final point = transform.toCanvasPoint(lines[i].startX, lines[i].startY);
      polygon.lineTo(point.dx, point.dy);
    }
    polygon.close();
    final polygonDirection = _polygonDirection(lines);

    final fill = Paint()
      ..color = _withOpacity(
        bundle.plasterCeiling ? Colors.blue : Colors.grey,
        selectionMode ? 0.20 : 0.08,
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(polygon, fill);
    final visibleConstraintKeys = {
      for (final visual in constraintVisuals) visual.key,
    };
    final fullyConstrained = _isDocumentFullyConstrained(document);
    final highlightedLineIds = <int>{
      for (final key in highlightedConstraintKeys) key.lineId,
    };
    for (final key in highlightedConstraintKeys) {
      if (key.type != RoomEditorConstraintType.parallel) {
        continue;
      }
      for (final constraint in document.constraints) {
        if (RoomEditorConstraintKey.fromConstraint(constraint) != key) {
          continue;
        }
        final targetLineId = constraint.targetValue;
        if (targetLineId != null) {
          highlightedLineIds.add(targetLineId);
        }
        break;
      }
    }
    final baseLineColor = fullyConstrained ? Colors.black : Colors.blue;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final start = transform.toCanvasPoint(line.startX, line.startY);
      final endPoint = RoomCanvasGeometry.lineEnd(lines, i);
      final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
      final isHighlighted = highlightedLineIds.contains(line.id);
      final isSelected = selectedLineIndices.contains(i);
      final isSelectedIntersection = selectedIntersectionIndices.contains(i);
      final effectiveLineColor = isHighlighted
          ? const Color(0xFFFF6B6B)
          : isSelected
          ? Colors.orange
          : baseLineColor;
      final paint = Paint()
        ..color = effectiveLineColor
        ..strokeWidth = isSelected ? 5 : 3;
      final vertexColor = isHighlighted
          ? const Color(0xFFFF6B6B)
          : isSelectedIntersection
          ? Colors.orange
          : baseLineColor;
      canvas
        ..drawLine(start, end, paint)
        ..drawCircle(
          start,
          isSelectedIntersection ? 7 : 6,
          Paint()..color = vertexColor,
        );
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final segmentLength = sqrt(dx * dx + dy * dy);
      final tangent = segmentLength == 0
          ? const Offset(1, 0)
          : Offset(dx / segmentLength, dy / segmentLength);
      final normal = segmentLength == 0
          ? const Offset(0, -1)
          : Offset(-dy / segmentLength, dx / segmentLength);
      final outsideNormal = polygonDirection >= 0 ? -normal : normal;
      final wallLabelPainter = TextPainter(
        text: TextSpan(
          text: 'W${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final wallLabelOffset =
          mid +
          outsideNormal * 20 -
          tangent * 24 -
          Offset(wallLabelPainter.width / 2, wallLabelPainter.height / 2);
      final wallLabelBounds = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          wallLabelOffset.dx - 5,
          wallLabelOffset.dy - 2,
          wallLabelPainter.width + 10,
          wallLabelPainter.height + 4,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        wallLabelBounds,
        Paint()..color = _withOpacity(Colors.black, 0.8),
      );
      wallLabelPainter.paint(canvas, wallLabelOffset);
      final hasVisibleLengthConstraint = visibleConstraintKeys.contains(
        RoomEditorConstraintKey(
          lineId: line.id,
          type: RoomEditorConstraintType.lineLength,
        ),
      );
      if (!hasVisibleLengthConstraint) {
        final labelText = RoomCanvasGeometry.formatDisplayLength(
          line.length,
          bundle.unitSystem,
        );
        final labelPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelOffset =
            mid +
            outsideNormal * 40 -
            Offset(labelPainter.width / 2, labelPainter.height / 2);
        final labelBounds = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            labelOffset.dx - 4,
            labelOffset.dy - 2,
            labelPainter.width + 8,
            labelPainter.height + 4,
          ),
          const Radius.circular(6),
        );
        final labelFill = Paint()
          ..color = isSelected
              ? _withOpacity(const Color(0xFFFFE2BF), 0.96)
              : _withOpacity(Colors.white, 0.92);
        canvas.drawRRect(labelBounds, labelFill);
        if (isSelected) {
          canvas.drawRRect(
            labelBounds,
            Paint()
              ..color = _withOpacity(Colors.orange, 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
        labelPainter.paint(canvas, labelOffset);
      }
      _paintOpeningsForLine(
        canvas: canvas,
        line: line,
        start: start,
        end: end,
        normal: normal,
        selectedOpeningId: selectedOpeningIndex == null
            ? null
            : bundle.openings[selectedOpeningIndex!].id,
      );
    }

    for (final constraintVisual in constraintVisuals) {
      constraintVisual.paint(canvas);
    }
  }

  double _polygonDirection(List<RoomEditorLine> lines) {
    var area = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final end = RoomCanvasGeometry.lineEnd(lines, i);
      area += (line.startX * end.y) - (end.x * line.startY);
    }
    return area;
  }

  void _paintOpeningsForLine({
    required Canvas canvas,
    required RoomEditorLine line,
    required Offset start,
    required Offset end,
    required Offset normal,
    required int? selectedOpeningId,
  }) {
    final openings = bundle.openings
        .where((opening) => opening.lineId == line.id)
        .toList();
    if (openings.isEmpty) {
      return;
    }

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final canvasLength = sqrt(dx * dx + dy * dy);
    if (canvasLength == 0 || line.length <= 0) {
      return;
    }

    final direction = Offset(dx / canvasLength, dy / canvasLength);
    final markerOffset = normal * 10;

    for (final opening in openings) {
      final openingStartRatio = opening.offsetFromStart / line.length;
      final openingEndRatio =
          (opening.offsetFromStart + opening.width) / line.length;
      final openingStart =
          start + direction * (canvasLength * openingStartRatio) + markerOffset;
      final openingEnd =
          start + direction * (canvasLength * openingEndRatio) + markerOffset;
      final paint = Paint()
        ..color = opening.id == selectedOpeningId
            ? Colors.orangeAccent
            : opening.type == RoomEditorOpeningType.door
            ? Colors.brown.shade300
            : Colors.lightBlueAccent
        ..strokeWidth = opening.id == selectedOpeningId ? 8 : 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(openingStart, openingEnd, paint);

      final markerMid = Offset(
        (openingStart.dx + openingEnd.dx) / 2,
        (openingStart.dy + openingEnd.dy) / 2,
      );
      final markerLabel = opening.type == RoomEditorOpeningType.door
          ? 'D'
          : 'W';
      final labelPainter = TextPainter(
        text: TextSpan(
          text: markerLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final markerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: markerMid + normal * 14,
          width: labelPainter.width + 10,
          height: labelPainter.height + 6,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        markerRect,
        Paint()..color = _withOpacity(Colors.black, 0.75),
      );
      labelPainter.paint(
        canvas,
        Offset(
          markerRect.left + (markerRect.width - labelPainter.width) / 2,
          markerRect.top + (markerRect.height - labelPainter.height) / 2,
        ),
      );
    }

    for (final constraintVisual in constraintVisuals) {
      constraintVisual.paint(canvas);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    if (!showGrid || bundle.lines.isEmpty) {
      return;
    }
    final gridSize = RoomCanvasGeometry.defaultGridSize(bundle.unitSystem);
    final gridPaint = Paint()
      ..color = _withOpacity(Colors.grey, 0.16)
      ..strokeWidth = 1;
    final startGridX = transform.gridStartX(bundle.unitSystem);
    final startGridY = transform.gridStartY(bundle.unitSystem);
    final endGridX = transform.gridEndX(bundle.unitSystem);
    final endGridY = transform.gridEndY(bundle.unitSystem);
    for (var x = startGridX; x <= endGridX; x += gridSize) {
      final canvasX = transform.canvasXForWorldX(x);
      canvas.drawLine(
        Offset(canvasX, 0),
        Offset(canvasX, size.height),
        gridPaint,
      );
    }
    for (var y = startGridY; y <= endGridY; y += gridSize) {
      final canvasY = transform.canvasYForWorldY(y);
      canvas.drawLine(
        Offset(0, canvasY),
        Offset(size.width, canvasY),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.selectionMode != selectionMode ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.constraintVisuals != constraintVisuals ||
      oldDelegate.highlightedConstraintKeys.length !=
          highlightedConstraintKeys.length ||
      !oldDelegate.highlightedConstraintKeys.containsAll(
        highlightedConstraintKeys,
      ) ||
      oldDelegate.selectedLineIndices.length != selectedLineIndices.length ||
      !oldDelegate.selectedLineIndices.containsAll(selectedLineIndices) ||
      oldDelegate.selectedIntersectionIndices.length !=
          selectedIntersectionIndices.length ||
      !oldDelegate.selectedIntersectionIndices.containsAll(
        selectedIntersectionIndices,
      ) ||
      oldDelegate.selectedOpeningIndex != selectedOpeningIndex;
}

bool _isDocumentFullyConstrained(RoomEditorDocument document) {
  final lines = document.bundle.lines;
  if (lines.isEmpty) {
    return false;
  }
  final lineLengthIds = <int>{};
  final orientedIds = <int>{};
  final angleIds = <int>{};
  for (final constraint in document.constraints) {
    switch (constraint.type) {
      case RoomEditorConstraintType.lineLength:
        lineLengthIds.add(constraint.lineId);
      case RoomEditorConstraintType.horizontal:
      case RoomEditorConstraintType.vertical:
      case RoomEditorConstraintType.parallel:
        orientedIds.add(constraint.lineId);
      case RoomEditorConstraintType.jointAngle:
        angleIds.add(constraint.lineId);
    }
  }
  return lines.every(
    (line) =>
        lineLengthIds.contains(line.id) &&
        orientedIds.contains(line.id) &&
        angleIds.contains(line.id),
  );
}

enum _ConstraintVisualKind { badge, dimension }

class RoomEditorConstraintVisualDebug {
  final RoomEditorConstraintKey key;
  final String kind;
  final Rect hitBox;
  final Offset anchor;
  final Offset? center;
  final Offset? lineStart;
  final Offset? lineEnd;

  const RoomEditorConstraintVisualDebug({
    required this.key,
    required this.kind,
    required this.hitBox,
    required this.anchor,
    this.center,
    this.lineStart,
    this.lineEnd,
  });
}

class _ConstraintVisual {
  final RoomEditorConstraintKey key;
  final _ConstraintVisualKind kind;
  final bool selected;
  final bool attention;
  final Offset anchor;
  final Offset anchorWorld;
  final Rect hitBox;
  final Offset? center;
  final Offset? lineStart;
  final Offset? lineEnd;
  final Offset? extensionStart;
  final Offset? extensionEnd;
  final Offset? dimensionAnchorStart;
  final Offset? dimensionAnchorEnd;
  final Offset? dragNormalWorld;
  final String? label;
  final IconData? icon;
  final String? badgeText;

  const _ConstraintVisual({
    required this.key,
    required this.kind,
    required this.selected,
    required this.attention,
    required this.anchor,
    required this.anchorWorld,
    required this.hitBox,
    this.center,
    this.lineStart,
    this.lineEnd,
    this.extensionStart,
    this.extensionEnd,
    this.dimensionAnchorStart,
    this.dimensionAnchorEnd,
    this.dragNormalWorld,
    this.label,
    this.icon,
    this.badgeText,
  });

  bool contains(Offset point) {
    if (hitBox.contains(point)) {
      return true;
    }
    if (kind == _ConstraintVisualKind.dimension) {
      if (lineStart != null &&
          lineEnd != null &&
          _distanceToSegment(point, lineStart!, lineEnd!) <= 10) {
        return true;
      }
      if (dimensionAnchorStart != null &&
          extensionStart != null &&
          _distanceToSegment(point, dimensionAnchorStart!, extensionStart!) <=
              8) {
        return true;
      }
      if (dimensionAnchorEnd != null &&
          extensionEnd != null &&
          _distanceToSegment(point, dimensionAnchorEnd!, extensionEnd!) <= 8) {
        return true;
      }
    }
    if (center != null && _distanceToSegment(point, anchor, center!) <= 8) {
      return true;
    }
    return false;
  }

  Offset offsetForDrag(Offset canvasPosition, _CanvasTransform transform) {
    final worldPoint = transform.toWorldOffset(canvasPosition);
    if (kind == _ConstraintVisualKind.dimension && dragNormalWorld != null) {
      final delta = worldPoint - anchorWorld;
      final projected =
          (delta.dx * dragNormalWorld!.dx) + (delta.dy * dragNormalWorld!.dy);
      final sign = projected == 0 ? 1.0 : projected.sign;
      final distance =
          max(projected.abs(), transform.worldDistanceForCanvasDistance(24)) *
          sign;
      return dragNormalWorld! * distance;
    }
    return worldPoint - anchorWorld;
  }

  void paint(Canvas canvas) {
    switch (kind) {
      case _ConstraintVisualKind.badge:
        _paintBadge(canvas);
      case _ConstraintVisualKind.dimension:
        _paintDimension(canvas);
    }
  }

  void _paintBadge(Canvas canvas) {
    if (center == null || (icon == null && badgeText == null)) {
      return;
    }
    final leaderUnderlay = Paint()
      ..color = _withOpacity(Colors.black, 0.95)
      ..strokeWidth = selected ? 4.2 : 3.2;
    final accentColor = attention
        ? const Color(0xFFFF6B6B)
        : selected
        ? const Color(0xFFFFB84D)
        : Colors.white;
    final leaderPaint = Paint()
      ..color = accentColor
      ..strokeWidth = selected ? 2.4 : 1.8;
    canvas
      ..drawLine(anchor, center!, leaderUnderlay)
      ..drawLine(anchor, center!, leaderPaint);
    final badgeRect = RRect.fromRectAndRadius(hitBox, const Radius.circular(8));
    canvas
      ..drawRRect(
        badgeRect,
        Paint()
          ..color = selected
              ? const Color(0xFF2E1D08)
              : attention
              ? const Color(0xFF2A1010)
              : const Color(0xFF101418),
      )
      ..drawRRect(
        badgeRect,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.0 : 1.2,
      );
    final painter = TextPainter(
      text: TextSpan(
        text: badgeText ?? String.fromCharCode(icon!.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: badgeText == null ? 16 : 15,
          height: 1,
          fontWeight: badgeText == null ? FontWeight.normal : FontWeight.w700,
          color: accentColor,
          fontFamily: badgeText == null ? icon!.fontFamily : null,
          package: badgeText == null ? icon!.fontPackage : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        hitBox.left + (hitBox.width - painter.width) / 2,
        hitBox.top + (hitBox.height - painter.height) / 2,
      ),
    );
  }

  void _paintDimension(Canvas canvas) {
    if (lineStart == null ||
        lineEnd == null ||
        extensionStart == null ||
        extensionEnd == null ||
        dimensionAnchorStart == null ||
        dimensionAnchorEnd == null ||
        label == null) {
      return;
    }
    final strokeColor = attention
        ? const Color(0xFFFF6B6B)
        : selected
        ? const Color(0xFFFFB84D)
        : Colors.white;
    final underlayPaint = Paint()
      ..color = _withOpacity(Colors.black, 0.95)
      ..strokeWidth = selected ? 4.2 : 3.2;
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = selected ? 2.4 : 1.4;
    canvas
      ..drawLine(dimensionAnchorStart!, extensionStart!, underlayPaint)
      ..drawLine(dimensionAnchorEnd!, extensionEnd!, underlayPaint)
      ..drawLine(lineStart!, lineEnd!, underlayPaint)
      ..drawLine(dimensionAnchorStart!, extensionStart!, strokePaint)
      ..drawLine(dimensionAnchorEnd!, extensionEnd!, strokePaint)
      ..drawLine(lineStart!, lineEnd!, strokePaint);
    _paintDimensionTick(canvas, lineStart!, lineEnd!, underlayPaint);
    _paintDimensionTick(canvas, lineEnd!, lineStart!, underlayPaint);
    _paintDimensionTick(canvas, lineStart!, lineEnd!, strokePaint);
    _paintDimensionTick(canvas, lineEnd!, lineStart!, strokePaint);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: selected ? const Color(0xFFFFB84D) : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelRect = RRect.fromRectAndRadius(hitBox, const Radius.circular(8));
    canvas
      ..drawRRect(
        labelRect,
        Paint()
          ..color = selected
              ? const Color(0xFF2E1D08)
              : attention
              ? const Color(0xFF2A1010)
              : const Color(0xFF101418),
      )
      ..drawRRect(
        labelRect,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.0 : 1.2,
      );
    labelPainter.paint(
      canvas,
      Offset(
        hitBox.left + (hitBox.width - labelPainter.width) / 2,
        hitBox.top + (hitBox.height - labelPainter.height) / 2,
      ),
    );
  }

  void _paintDimensionTick(
    Canvas canvas,
    Offset point,
    Offset otherPoint,
    Paint paint,
  ) {
    final direction = otherPoint - point;
    if (direction.distance == 0) {
      return;
    }
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    const tickLength = 6.0;
    canvas.drawLine(
      point - unit * tickLength + normal * tickLength,
      point + unit * tickLength - normal * tickLength,
      paint,
    );
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }
    final t =
        (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + dx * clamped, a.dy + dy * clamped);
    return (p - projection).distance;
  }
}

List<_ConstraintVisual> buildConstraintVisuals({
  required RoomEditorDocument document,
  required RoomEditorSelection selection,
  required bool showAllConstraints,
  required Map<RoomEditorConstraintKey, Offset> customOffsets,
  required _CanvasTransform transform,
  Set<RoomEditorConstraintKey> highlightedKeys = const {},
}) {
  final lines = document.bundle.lines;
  if (lines.isEmpty || document.constraints.isEmpty) {
    return const [];
  }
  final polygonDirection = _polygonDirection(lines);
  final visibleConstraints = document.constraints.where((constraint) {
    final key = RoomEditorConstraintKey.fromConstraint(constraint);
    if (constraint.type == RoomEditorConstraintType.lineLength) {
      return true;
    }
    if (selection.selectedConstraintKey == key) {
      return true;
    }
    if (highlightedKeys.contains(key)) {
      return true;
    }
    if (showAllConstraints) {
      return true;
    }
    final selectedLineIds = {
      for (final index in selection.selectedLineIndices)
        if (index >= 0 && index < lines.length) lines[index].id,
    };
    if ((selectedLineIds.contains(constraint.lineId) ||
            selectedLineIds.contains(constraint.targetValue)) &&
        constraint.type != RoomEditorConstraintType.jointAngle) {
      return true;
    }
    final selectedIntersectionIds = {
      for (final index in selection.selectedIntersectionIndices)
        if (index >= 0 && index < lines.length) lines[index].id,
    };
    if (selectedIntersectionIds.contains(constraint.lineId) &&
        constraint.type == RoomEditorConstraintType.jointAngle) {
      return true;
    }
    return false;
  });

  final visuals = <_ConstraintVisual>[];
  final baseOffset = transform.worldDistanceForCanvasDistance(68);
  final tangentShiftDistance = transform.worldDistanceForCanvasDistance(24);
  for (final constraint in visibleConstraints) {
    final lineIndex = lines.indexWhere((line) => line.id == constraint.lineId);
    if (lineIndex < 0) {
      continue;
    }
    final line = lines[lineIndex];
    final startWorld = Offset(line.startX.toDouble(), line.startY.toDouble());
    final endPoint = RoomCanvasGeometry.lineEnd(lines, lineIndex);
    final endWorld = Offset(endPoint.x.toDouble(), endPoint.y.toDouble());
    final direction = endWorld - startWorld;
    if (direction.distance == 0) {
      continue;
    }
    final tangent = direction / direction.distance;
    final normal = Offset(-tangent.dy, tangent.dx);
    final outsideNormal = polygonDirection >= 0 ? -normal : normal;
    final key = RoomEditorConstraintKey.fromConstraint(constraint);
    final selected = selection.selectedConstraintKey == key;
    final attention = highlightedKeys.contains(key);

    switch (constraint.type) {
      case RoomEditorConstraintType.lineLength:
        final offsetWorld = customOffsets[key] ?? outsideNormal * baseOffset;
        final dimensionStartWorld = startWorld + offsetWorld;
        final dimensionEndWorld = endWorld + offsetWorld;
        final dimensionStart = transform.toCanvasOffset(dimensionStartWorld);
        final dimensionEnd = transform.toCanvasOffset(dimensionEndWorld);
        final label = RoomCanvasGeometry.formatDisplayLength(
          constraint.targetValue ?? line.length,
          document.bundle.unitSystem,
        );
        final labelPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final midpoint = Offset(
          (dimensionStart.dx + dimensionEnd.dx) / 2,
          (dimensionStart.dy + dimensionEnd.dy) / 2,
        );
        final hitBox = Rect.fromCenter(
          center: midpoint,
          width: labelPainter.width + 18,
          height: labelPainter.height + 10,
        );
        visuals.add(
          _ConstraintVisual(
            key: key,
            kind: _ConstraintVisualKind.dimension,
            selected: selected,
            attention: attention,
            anchor: transform.toCanvasOffset((startWorld + endWorld) / 2),
            anchorWorld: (startWorld + endWorld) / 2,
            hitBox: hitBox,
            lineStart: dimensionStart,
            lineEnd: dimensionEnd,
            extensionStart: dimensionStart,
            extensionEnd: dimensionEnd,
            dimensionAnchorStart: transform.toCanvasOffset(startWorld),
            dimensionAnchorEnd: transform.toCanvasOffset(endWorld),
            dragNormalWorld: outsideNormal,
            label: label,
          ),
        );
      case RoomEditorConstraintType.horizontal:
      case RoomEditorConstraintType.vertical:
      case RoomEditorConstraintType.parallel:
        final anchorWorld = (startWorld + endWorld) / 2;
        final tangentShift =
            constraint.type == RoomEditorConstraintType.horizontal
            ? tangent * tangentShiftDistance
            : constraint.type == RoomEditorConstraintType.vertical
            ? -tangent * tangentShiftDistance
            : Offset.zero;
        final offsetWorld =
            customOffsets[key] ??
            (outsideNormal * transform.worldDistanceForCanvasDistance(42)) +
                tangentShift;
        final center = transform.toCanvasOffset(anchorWorld + offsetWorld);
        visuals.add(
          _ConstraintVisual(
            key: key,
            kind: _ConstraintVisualKind.badge,
            selected: selected,
            attention: attention,
            anchor: transform.toCanvasOffset(anchorWorld),
            anchorWorld: anchorWorld,
            center: center,
            hitBox: Rect.fromCenter(center: center, width: 26, height: 26),
            badgeText: switch (constraint.type) {
              RoomEditorConstraintType.horizontal => '—',
              RoomEditorConstraintType.vertical => '|',
              RoomEditorConstraintType.parallel => '||',
              _ => null,
            },
          ),
        );
      case RoomEditorConstraintType.jointAngle:
        final previousIndex = (lineIndex - 1 + lines.length) % lines.length;
        final previousStart = Offset(
          lines[previousIndex].startX.toDouble(),
          lines[previousIndex].startY.toDouble(),
        );
        final incoming = startWorld - previousStart;
        if (incoming.distance == 0) {
          continue;
        }
        final incomingDirection = incoming / incoming.distance;
        final outgoingDirection = direction / direction.distance;
        var bisector = -(incomingDirection + outgoingDirection);
        if (bisector.distance == 0) {
          bisector = outsideNormal;
        } else {
          bisector = bisector / bisector.distance;
        }
        final offsetWorld =
            customOffsets[key] ??
            bisector * transform.worldDistanceForCanvasDistance(52);
        final center = transform.toCanvasOffset(startWorld + offsetWorld);
        visuals.add(
          _ConstraintVisual(
            key: key,
            kind: _ConstraintVisualKind.badge,
            selected: selected,
            attention: attention,
            anchor: transform.toCanvasOffset(startWorld),
            anchorWorld: startWorld,
            center: center,
            hitBox: Rect.fromCenter(center: center, width: 26, height: 26),
            icon: Icons.architecture,
          ),
        );
    }
  }
  return visuals;
}

List<RoomEditorConstraintVisualDebug> debugDescribeConstraintVisuals({
  required RoomEditorDocument document,
  required RoomEditorSelection selection,
  required bool showAllConstraints,
  Map<RoomEditorConstraintKey, Offset> customOffsets = const {},
  Size size = const Size(800, 600),
}) {
  final lines = document.bundle.lines;
  if (lines.isEmpty) {
    return const [];
  }
  final transform = _CanvasTransform(
    lines,
    size,
    bounds: _CanvasWorldBounds.fromLines(lines),
  );
  final visuals = buildConstraintVisuals(
    document: document,
    selection: selection,
    showAllConstraints: showAllConstraints,
    customOffsets: customOffsets,
    transform: transform,
  );
  return [
    for (final visual in visuals)
      RoomEditorConstraintVisualDebug(
        key: visual.key,
        kind: visual.kind.name,
        hitBox: visual.hitBox,
        anchor: visual.anchor,
        center: visual.center,
        lineStart: visual.lineStart,
        lineEnd: visual.lineEnd,
      ),
  ];
}

Rect _computeCanvasPaintBounds({
  required RoomEditorDocument document,
  required RoomEditorSelection selection,
  required bool showAllConstraints,
  required Map<RoomEditorConstraintKey, Offset> customOffsets,
  required _CanvasTransform transform,
}) {
  final lines = document.bundle.lines;
  if (lines.isEmpty) {
    return Rect.zero;
  }
  final polygonDirection = _polygonDirection(lines);
  Rect? bounds;

  void includeRect(Rect rect) {
    bounds = bounds == null ? rect : bounds!.expandToInclude(rect);
  }

  void includePoint(Offset point, {double radius = 0}) {
    includeRect(Rect.fromCircle(center: point, radius: radius));
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final start = transform.toCanvasPoint(line.startX, line.startY);
    final endPoint = RoomCanvasGeometry.lineEnd(lines, i);
    final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
    includePoint(start, radius: 8);
    includePoint(end, radius: 8);

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final segmentLength = sqrt(dx * dx + dy * dy);
    final tangent = segmentLength == 0
        ? const Offset(1, 0)
        : Offset(dx / segmentLength, dy / segmentLength);
    final normal = segmentLength == 0
        ? const Offset(0, -1)
        : Offset(-dy / segmentLength, dx / segmentLength);
    final outsideNormal = polygonDirection >= 0 ? -normal : normal;

    final wallLabelPainter = TextPainter(
      text: TextSpan(
        text: 'W${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final wallLabelOffset =
        mid +
        outsideNormal * 20 -
        tangent * 24 -
        Offset(wallLabelPainter.width / 2, wallLabelPainter.height / 2);
    includeRect(
      Rect.fromLTWH(
        wallLabelOffset.dx - 5,
        wallLabelOffset.dy - 2,
        wallLabelPainter.width + 10,
        wallLabelPainter.height + 4,
      ),
    );

    final labelText = RoomCanvasGeometry.formatDisplayLength(
      line.length,
      document.bundle.unitSystem,
    );
    final labelPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelOffset =
        mid +
        outsideNormal * 40 -
        Offset(labelPainter.width / 2, labelPainter.height / 2);
    includeRect(
      Rect.fromLTWH(
        labelOffset.dx - 4,
        labelOffset.dy - 2,
        labelPainter.width + 8,
        labelPainter.height + 4,
      ),
    );

    final openings = document.bundle.openings
        .where((opening) => opening.lineId == line.id)
        .toList();
    if (openings.isEmpty || segmentLength == 0 || line.length <= 0) {
      continue;
    }
    final direction = Offset(dx / segmentLength, dy / segmentLength);
    final markerOffset = normal * 10;
    for (final opening in openings) {
      final openingStartRatio = opening.offsetFromStart / line.length;
      final openingEndRatio =
          (opening.offsetFromStart + opening.width) / line.length;
      final openingStart =
          start +
          direction * (segmentLength * openingStartRatio) +
          markerOffset;
      final openingEnd =
          start + direction * (segmentLength * openingEndRatio) + markerOffset;
      includePoint(openingStart, radius: 6);
      includePoint(openingEnd, radius: 6);
      final markerMid = Offset(
        (openingStart.dx + openingEnd.dx) / 2,
        (openingStart.dy + openingEnd.dy) / 2,
      );
      final markerLabel = opening.type == RoomEditorOpeningType.door
          ? 'D'
          : 'W';
      final openingLabelPainter = TextPainter(
        text: TextSpan(
          text: markerLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      includeRect(
        Rect.fromCenter(
          center: markerMid + normal * 14,
          width: openingLabelPainter.width + 10,
          height: openingLabelPainter.height + 6,
        ),
      );
    }
  }

  final visuals = buildConstraintVisuals(
    document: document,
    selection: selection,
    showAllConstraints: showAllConstraints,
    customOffsets: customOffsets,
    transform: transform,
  );
  for (final visual in visuals) {
    includeRect(visual.hitBox);
    if (visual.lineStart != null) {
      includePoint(visual.lineStart!, radius: 8);
    }
    if (visual.lineEnd != null) {
      includePoint(visual.lineEnd!, radius: 8);
    }
    if (visual.extensionStart != null) {
      includePoint(visual.extensionStart!, radius: 8);
    }
    if (visual.extensionEnd != null) {
      includePoint(visual.extensionEnd!, radius: 8);
    }
    if (visual.dimensionAnchorStart != null) {
      includePoint(visual.dimensionAnchorStart!, radius: 8);
    }
    if (visual.dimensionAnchorEnd != null) {
      includePoint(visual.dimensionAnchorEnd!, radius: 8);
    }
    if (visual.center != null) {
      includePoint(visual.center!, radius: 16);
    }
    includePoint(visual.anchor, radius: 8);
  }

  return bounds ?? Rect.zero;
}

double _polygonDirection(List<RoomEditorLine> lines) {
  var area = 0.0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final end = RoomCanvasGeometry.lineEnd(lines, i);
    area += (line.startX * end.y) - (end.x * line.startY);
  }
  return area;
}

class _CanvasTransform {
  static const _horizontalPadding = 72.0;
  static const _verticalPadding = 72.0;

  final List<RoomEditorLine> lines;
  final Size size;
  late final double _scale;
  late final double _offsetX;
  late final double _offsetY;
  late final int _minX;
  late final int _minY;
  late final int _maxX;
  late final int _maxY;

  _CanvasTransform(
    this.lines,
    this.size, {
    required _CanvasWorldBounds bounds,
  }) {
    _minX = bounds.minX;
    _minY = bounds.minY;
    _maxX = bounds.maxX;
    _maxY = bounds.maxY;
    final width = (_maxX - _minX).abs().toDouble().clamp(1, double.infinity);
    final height = (_maxY - _minY).abs().toDouble().clamp(1, double.infinity);
    final availableWidth = max(1, size.width - (_horizontalPadding * 2));
    final availableHeight = max(1, size.height - (_verticalPadding * 2));
    _scale = availableWidth / width < availableHeight / height
        ? availableWidth / width
        : availableHeight / height;
    _offsetX = _horizontalPadding;
    _offsetY = _verticalPadding;
  }

  Offset toCanvasPoint(int x, int y) =>
      Offset(_offsetX + (x - _minX) * _scale, _offsetY + (y - _minY) * _scale);

  Offset toCanvasOffset(Offset worldPoint) => Offset(
    _offsetX + (worldPoint.dx - _minX) * _scale,
    _offsetY + (worldPoint.dy - _minY) * _scale,
  );

  double canvasXForWorldX(int x) => _offsetX + (x - _minX) * _scale;

  double canvasYForWorldY(int y) => _offsetY + (y - _minY) * _scale;

  RoomEditorIntPoint toWorld(Offset offset) => RoomEditorIntPoint(
    _minX + ((offset.dx - _offsetX) / _scale).round(),
    _minY + ((offset.dy - _offsetY) / _scale).round(),
  );

  Offset toWorldOffset(Offset offset) => Offset(
    _minX + ((offset.dx - _offsetX) / _scale),
    _minY + ((offset.dy - _offsetY) / _scale),
  );

  double worldDistanceForCanvasDistance(double canvasDistance) =>
      canvasDistance / _scale;

  int gridStartX(RoomEditorUnitSystem unitSystem) {
    final grid = RoomCanvasGeometry.defaultGridSize(unitSystem);
    final worldLeft = toWorld(Offset.zero).x;
    return (worldLeft / grid).floor() * grid;
  }

  int gridStartY(RoomEditorUnitSystem unitSystem) {
    final grid = RoomCanvasGeometry.defaultGridSize(unitSystem);
    final worldTop = toWorld(Offset.zero).y;
    return (worldTop / grid).floor() * grid;
  }

  int gridEndX(RoomEditorUnitSystem unitSystem) {
    final grid = RoomCanvasGeometry.defaultGridSize(unitSystem);
    final worldRight = toWorld(Offset(size.width, 0)).x;
    return (worldRight / grid).ceil() * grid;
  }

  int gridEndY(RoomEditorUnitSystem unitSystem) {
    final grid = RoomCanvasGeometry.defaultGridSize(unitSystem);
    final worldBottom = toWorld(Offset(0, size.height)).y;
    return (worldBottom / grid).ceil() * grid;
  }

  int? hitIntersection(Offset offset) {
    final candidates = hitIntersectionCandidates(offset);
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first.$1;
  }

  List<(int, double)> hitIntersectionCandidates(Offset offset) {
    final candidates = <(int, double)>[];
    for (var i = 0; i < lines.length; i++) {
      final point = toCanvasPoint(lines[i].startX, lines[i].startY);
      final distance = (point - offset).distance;
      if (distance <= 12) {
        candidates.add((i, distance));
      }
    }
    candidates.sort((left, right) => left.$2.compareTo(right.$2));
    return candidates;
  }

  List<(int, double)> hitLineCandidates(Offset offset) {
    final candidates = <(int, double)>[];
    for (var i = 0; i < lines.length; i++) {
      final start = toCanvasPoint(lines[i].startX, lines[i].startY);
      final endPoint = RoomCanvasGeometry.lineEnd(lines, i);
      final end = toCanvasPoint(endPoint.x, endPoint.y);
      final distance = _distanceToSegment(offset, start, end);
      if (distance <= 10) {
        candidates.add((i, distance));
      }
    }
    candidates.sort((left, right) => left.$2.compareTo(right.$2));
    return candidates;
  }

  int? hitOpening(List<RoomEditorOpening> openings, Offset offset) {
    for (var i = 0; i < openings.length; i++) {
      final opening = openings[i];
      final lineIndex = lines.indexWhere((line) => line.id == opening.lineId);
      if (lineIndex < 0) {
        continue;
      }
      final marker = _openingMarker(lines[lineIndex], opening);
      if (marker == null) {
        continue;
      }
      if (marker.contains(offset)) {
        return i;
      }
    }
    return null;
  }

  int openingDragAnchorOffset(
    List<RoomEditorOpening> openings,
    Offset offset,
    int openingIndex,
  ) {
    if (openingIndex < 0 || openingIndex >= openings.length) {
      return 0;
    }
    final opening = openings[openingIndex];
    final lineIndex = lines.indexWhere((line) => line.id == opening.lineId);
    if (lineIndex < 0) {
      return 0;
    }
    final line = lines[lineIndex];
    final end = RoomCanvasGeometry.lineEnd(lines, lineIndex);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0 || line.length <= 0) {
      return 0;
    }
    final world = toWorld(offset);
    final projected =
        ((world.x - line.startX) * dx + (world.y - line.startY) * dy) /
        lengthSquared;
    final positionOnLine = (projected * line.length).round();
    return (positionOnLine - opening.offsetFromStart).clamp(0, opening.width);
  }

  _OpeningMarker? _openingMarker(
    RoomEditorLine line,
    RoomEditorOpening opening,
  ) {
    final lineIndex = lines.indexOf(line);
    if (lineIndex < 0 || line.length <= 0) {
      return null;
    }
    final start = toCanvasPoint(line.startX, line.startY);
    final endPoint = RoomCanvasGeometry.lineEnd(lines, lineIndex);
    final end = toCanvasPoint(endPoint.x, endPoint.y);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final canvasLength = sqrt(dx * dx + dy * dy);
    if (canvasLength == 0) {
      return null;
    }
    final direction = Offset(dx / canvasLength, dy / canvasLength);
    final normal = Offset(-dy / canvasLength, dx / canvasLength);
    final markerOffset = normal * 10;
    final openingStartRatio = opening.offsetFromStart / line.length;
    final openingEndRatio =
        (opening.offsetFromStart + opening.width) / line.length;
    final openingStart =
        start + direction * (canvasLength * openingStartRatio) + markerOffset;
    final openingEnd =
        start + direction * (canvasLength * openingEndRatio) + markerOffset;
    final markerMid = Offset(
      (openingStart.dx + openingEnd.dx) / 2,
      (openingStart.dy + openingEnd.dy) / 2,
    );
    final badgeCenter = markerMid + normal * 14;
    return _OpeningMarker(
      start: openingStart,
      end: openingEnd,
      badgeHitBox: Rect.fromCircle(center: badgeCenter, radius: 12),
    );
  }

  bool hitPolygon(Offset offset) {
    final path = Path();
    final first = toCanvasPoint(lines.first.startX, lines.first.startY);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < lines.length; i++) {
      final point = toCanvasPoint(lines[i].startX, lines[i].startY);
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path.contains(offset);
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }
    final t =
        (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + dx * clamped, a.dy + dy * clamped);
    return (p - projection).distance;
  }
}

class _CanvasWorldBounds {
  static const _fitSafetyMargin = 16.0;

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  const _CanvasWorldBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  factory _CanvasWorldBounds.fromDocument({
    required RoomEditorDocument document,
    required RoomEditorSelection selection,
    required bool showAllConstraints,
    required Map<RoomEditorConstraintKey, Offset> customOffsets,
    required Size size,
  }) {
    final lineBounds = _CanvasWorldBounds.fromLines(document.bundle.lines);
    final baseTransform = _CanvasTransform(
      document.bundle.lines,
      size,
      bounds: lineBounds,
    );
    final paintBounds = _computeCanvasPaintBounds(
      document: document,
      selection: selection,
      showAllConstraints: showAllConstraints,
      customOffsets: customOffsets,
      transform: baseTransform,
    );
    final leftOverhang = max(0, -paintBounds.left);
    final topOverhang = max(0, -paintBounds.top);
    final rightOverhang = max(0, paintBounds.right - size.width);
    final bottomOverhang = max(0, paintBounds.bottom - size.height);
    final expandLeft = leftOverhang > 0 ? leftOverhang + _fitSafetyMargin : 0.0;
    final expandTop = topOverhang > 0 ? topOverhang + _fitSafetyMargin : 0.0;
    final expandRight = rightOverhang > 0
        ? rightOverhang + _fitSafetyMargin
        : 0.0;
    final expandBottom = bottomOverhang > 0
        ? bottomOverhang + _fitSafetyMargin
        : 0.0;
    if (expandLeft == 0 &&
        expandTop == 0 &&
        expandRight == 0 &&
        expandBottom == 0) {
      return lineBounds;
    }
    return _CanvasWorldBounds(
      minX:
          lineBounds.minX -
          baseTransform.worldDistanceForCanvasDistance(expandLeft).ceil(),
      minY:
          lineBounds.minY -
          baseTransform.worldDistanceForCanvasDistance(expandTop).ceil(),
      maxX:
          lineBounds.maxX +
          baseTransform.worldDistanceForCanvasDistance(expandRight).ceil(),
      maxY:
          lineBounds.maxY +
          baseTransform.worldDistanceForCanvasDistance(expandBottom).ceil(),
    );
  }

  factory _CanvasWorldBounds.fromLines(List<RoomEditorLine> lines) {
    final xs = lines.map((line) => line.startX).toList()..sort();
    final ys = lines.map((line) => line.startY).toList()..sort();
    return _CanvasWorldBounds(
      minX: xs.first,
      minY: ys.first,
      maxX: xs.last,
      maxY: ys.last,
    );
  }
}

class _OpeningMarker {
  final Offset start;
  final Offset end;
  final Rect badgeHitBox;

  const _OpeningMarker({
    required this.start,
    required this.end,
    required this.badgeHitBox,
  });

  bool contains(Offset point) {
    if (badgeHitBox.contains(point)) {
      return true;
    }
    return _distanceToSegment(point, start, end) <= 6;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }
    final t =
        (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + dx * clamped, a.dy + dy * clamped);
    return (p - projection).distance;
  }
}

Color _withOpacity(Color color, double opacity) =>
    color.withAlpha((255 * opacity).round().clamp(0, 255));
