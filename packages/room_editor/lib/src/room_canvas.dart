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
  final RoomEditorDocumentConstraintState documentConstraintState;
  final Map<RoomEditorConstraintKey, Offset> constraintVisualOffsets;
  final Map<int, Offset> wallLabelOffsets;
  final Set<RoomEditorConstraintKey> highlightedConstraintKeys;
  final Set<int> highlightedImplicitLengthLineIndices;
  final Map<int, RoomEditorLinePresentation> linePresentations;
  final Map<int, RoomEditorIntersectionPresentation> intersectionPresentations;
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
    required this.documentConstraintState,
    required this.constraintVisualOffsets,
    required this.wallLabelOffsets,
    required this.highlightedConstraintKeys,
    required this.highlightedImplicitLengthLineIndices,
    required this.linePresentations,
    required this.intersectionPresentations,
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
  Offset? _gestureStartViewportPosition;
  int? _secondaryPanPointer;
  Offset? _secondaryPanPosition;
  var _activePointerCount = 0;
  _CanvasTransform? _dragTransform;
  _CanvasWorldBounds? _dragViewportBounds;
  _CanvasWorldBounds? _zoomViewportBounds;
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
      _zoomViewportBounds = null;
      _transformationController.value = Matrix4.identity();
    }
  }

  void _handlePointerSignal(
    PointerSignalEvent event,
    Size size,
    _CanvasTransform transform,
    _CanvasWorldBounds fitBounds,
    _CanvasWorldBounds viewportBounds,
  ) {
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

      final scaleDelta = exp(-scrollEvent.scrollDelta.dy / 240);
      final currentZoom = fitBounds.zoomRatioFor(viewportBounds);
      final nextZoom = (currentZoom * scaleDelta).clamp(0.5, 4.0);
      if ((nextZoom - currentZoom).abs() < 0.001) {
        return;
      }

      final canvasPosition = _toCanvasSpace(localPosition);
      final worldAnchor = transform.toWorldOffset(canvasPosition);
      final nextBounds = fitBounds.zoomed(
        zoom: nextZoom,
        anchor: worldAnchor,
        anchorCanvasPosition: canvasPosition,
        size: size,
      );
      if (nextZoom <= 1.001) {
        _zoomViewportBounds = nextZoom >= 0.999 ? null : nextBounds;
      } else {
        _zoomViewportBounds = nextBounds;
      }
      setState(() {});
    });
  }

  Offset _toCanvasSpace(Offset viewportPosition) {
    final inverse = Matrix4.inverted(_transformationController.value);
    return MatrixUtils.transformPoint(inverse, viewportPosition);
  }

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

  bool get _isDraggingGeometry =>
      _dragIndex != null ||
      _dragLineIndex != null ||
      _dragOpeningIndex != null ||
      _dragConstraintKey != null;

  bool get _hasPendingGeometryDrag =>
      _pendingDragIndex != null ||
      _pendingDragLineIndex != null ||
      _pendingDragOpeningIndex != null ||
      _pendingDragConstraintKey != null;

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
    _gestureStartViewportPosition = null;
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
    _gestureStartViewportPosition = null;
    _gestureStartViewportPosition = null;
    _dragTransform = null;
    _dragViewportBounds = null;
  }

  bool _isSecondaryMousePanEvent(PointerEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      (event.buttons & kSecondaryMouseButton) != 0;

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
      if (!widget.highlightedImplicitLengthLineIndices.contains(i)) {
        continue;
      }
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

  List<_OpeningDimensionVisual> _openingDimensionVisuals(
    _CanvasTransform transform,
  ) => buildOpeningDimensionVisuals(
    document: widget.document,
    selection: widget.selection,
    transform: transform,
  );

  _OpeningDimensionVisual? _hitOpeningDimensionLabel(
    Offset canvasPosition,
    _CanvasTransform transform,
  ) {
    for (final visual in _openingDimensionVisuals(transform).reversed) {
      if (visual.contains(canvasPosition)) {
        return visual;
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
    _gestureStartViewportPosition = event.localPosition;
    final canvasPosition = _toCanvasSpace(event.localPosition);
    _gestureStartPosition = canvasPosition;
    final constraintVisual = _hitConstraint(canvasPosition, transform);
    if (constraintVisual != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= transform.worldBounds;
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
      _dragViewportBounds ??= transform.worldBounds;
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
      _dragViewportBounds ??= transform.worldBounds;
      _pendingDragLineIndex = null;
      return;
    }
    final lineCandidates = transform.hitLineCandidates(canvasPosition);
    _pendingDragLineIndex = lineCandidates.isEmpty
        ? null
        : lineCandidates.first.$1;
    if (_pendingDragLineIndex != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= transform.worldBounds;
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
    final viewportStart = _gestureStartViewportPosition;
    final dragThreshold = _pendingDragConstraintKey != null ? 3.0 : 6.0;
    if (start == null ||
        viewportStart == null ||
        (event.localPosition - viewportStart).distance <= dragThreshold) {
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

    final openingDimensionVisual = _hitOpeningDimensionLabel(
      localPosition,
      transform,
    );
    if (openingDimensionVisual != null) {
      await widget.callbacks.onTapOpeningDimension(openingDimensionVisual.key);
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
    Offset canvasPosition,
    _CanvasTransform transform,
  ) async {
    final constraintVisual = _hitConstraint(canvasPosition, transform);
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
      final fitBounds = _CanvasWorldBounds.fromDocument(
        document: widget.document,
        selection: widget.selection,
        showAllConstraints: widget.showAllConstraints,
        customOffsets: widget.constraintVisualOffsets,
        linePresentations: widget.linePresentations,
        intersectionPresentations: widget.intersectionPresentations,
        size: size,
      );
      final viewportBounds =
          _dragViewportBounds ?? _zoomViewportBounds ?? fitBounds;
      final transform = _CanvasTransform(
        _bundle.lines,
        size,
        bounds: viewportBounds,
      );
      final constraintVisuals = _constraintVisuals(transform);
      return ColoredBox(
        color: const Color(0xFF1B222A),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => unawaited(
            _handleTapSelection(
              context,
              _toCanvasSpace(details.localPosition),
              transform,
            ),
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _handlePointerDown(event, transform),
            onPointerMove: (event) => _handlePointerMove(event, transform),
            onPointerUp: (event) => _handlePointerEnd(event.pointer),
            onPointerCancel: (event) => _handlePointerEnd(event.pointer),
            onPointerSignal: (event) => _handlePointerSignal(
              event,
              size,
              transform,
              fitBounds,
              viewportBounds,
            ),
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1,
              maxScale: 1,
              panEnabled: !_isDraggingGeometry && !_hasPendingGeometryDrag,
              scaleEnabled: false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (details) => unawaited(
                  _handleLongPress(details.localPosition, transform),
                ),
                child: CustomPaint(
                  size: size,
                  painter: _RoomPainter(
                    document: widget.document,
                    transform: transform,
                    selectionMode: widget.selectionMode,
                    showGrid: widget.showGrid,
                    documentConstraintState: widget.documentConstraintState,
                    constraintVisuals: constraintVisuals,
                    highlightedConstraintKeys: widget.highlightedConstraintKeys,
                    highlightedImplicitLengthLineIndices:
                        widget.highlightedImplicitLengthLineIndices,
                    linePresentations: widget.linePresentations,
                    intersectionPresentations: widget.intersectionPresentations,
                    selectedLineIndices: widget.selection.selectedLineIndices,
                    selectedIntersectionIndices:
                        widget.selection.selectedIntersectionIndices,
                    selectedOpeningIndex: widget.selection.selectedOpeningIndex,
                    selectedOpeningDimensionKey:
                        widget.selection.selectedOpeningDimensionKey,
                  ),
                ),
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
  final RoomEditorDocumentConstraintState documentConstraintState;
  final List<_ConstraintVisual> constraintVisuals;
  final Set<RoomEditorConstraintKey> highlightedConstraintKeys;
  final Set<int> highlightedImplicitLengthLineIndices;
  final Map<int, RoomEditorLinePresentation> linePresentations;
  final Map<int, RoomEditorIntersectionPresentation> intersectionPresentations;
  final Set<int> selectedLineIndices;
  final Set<int> selectedIntersectionIndices;
  final int? selectedOpeningIndex;
  final RoomEditorOpeningDimensionKey? selectedOpeningDimensionKey;

  RoomEditorBundle get bundle => document.bundle;

  const _RoomPainter({
    required this.document,
    required this.transform,
    required this.selectionMode,
    required this.showGrid,
    required this.documentConstraintState,
    required this.constraintVisuals,
    required this.highlightedConstraintKeys,
    required this.highlightedImplicitLengthLineIndices,
    required this.linePresentations,
    required this.intersectionPresentations,
    required this.selectedLineIndices,
    required this.selectedIntersectionIndices,
    required this.selectedOpeningIndex,
    required this.selectedOpeningDimensionKey,
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
    final fullyConstrained =
        documentConstraintState ==
        RoomEditorDocumentConstraintState.fullyConstrained;
    final highlightedLineIds = <int>{
      for (final key in highlightedConstraintKeys) key.lineId,
      for (final index in highlightedImplicitLengthLineIndices)
        if (index >= 0 && index < lines.length) lines[index].id,
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
      final linePresentation = linePresentations[line.id];
      final intersectionPresentation = intersectionPresentations[line.id];
      final effectiveLineColor = isHighlighted
          ? const Color(0xFFFF6B6B)
          : isSelected
          ? Colors.orange
          : linePresentation?.color ?? baseLineColor;
      final paint = Paint()
        ..color = effectiveLineColor
        ..strokeWidth = isSelected ? 5 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final vertexColor = isHighlighted
          ? const Color(0xFFFF6B6B)
          : isSelectedIntersection
          ? Colors.orange
          : intersectionPresentation?.color ?? baseLineColor;
      if (linePresentation?.style == RoomEditorLineStrokeStyle.dashed) {
        _drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }
      canvas.drawCircle(
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
      final lineBadge = linePresentation?.badge;
      if (lineBadge != null) {
        _paintExternalBadge(
          canvas: canvas,
          anchor: mid,
          center: mid + outsideNormal * 58,
          badge: lineBadge,
        );
      }
      final intersectionBadge = intersectionPresentation?.badge;
      if (intersectionBadge != null) {
        _paintExternalBadge(
          canvas: canvas,
          anchor: start,
          center: start + outsideNormal * 34,
          badge: intersectionBadge,
        );
      }
      final hasVisibleLengthConstraint = visibleConstraintKeys.contains(
        RoomEditorConstraintKey(
          lineId: line.id,
          type: RoomEditorConstraintType.lineLength,
        ),
      );
      final isImplicitLengthHighlighted = highlightedImplicitLengthLineIndices
          .contains(i);
      if (!hasVisibleLengthConstraint && isImplicitLengthHighlighted) {
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
          ..color = isImplicitLengthHighlighted
              ? _withOpacity(const Color(0xFFFFE5E5), 0.96)
              : isSelected
              ? _withOpacity(const Color(0xFFFFE2BF), 0.96)
              : _withOpacity(Colors.white, 0.92);
        canvas.drawRRect(labelBounds, labelFill);
        if (isImplicitLengthHighlighted || isSelected) {
          canvas.drawRRect(
            labelBounds,
            Paint()
              ..color = isImplicitLengthHighlighted
                  ? _withOpacity(const Color(0xFFFF6B6B), 0.95)
                  : _withOpacity(Colors.orange, 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
        if (isImplicitLengthHighlighted) {
          TextPainter(text: const TextSpan(), textDirection: TextDirection.ltr)
            ..text = TextSpan(
              text: labelText,
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
            ..layout()
            ..paint(canvas, labelOffset);
        } else {
          labelPainter.paint(canvas, labelOffset);
        }
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

    final openingDimensionVisuals = buildOpeningDimensionVisuals(
      document: document,
      selection: RoomEditorSelection(
        selectedOpeningIndex: selectedOpeningIndex,
        selectedOpeningDimensionKey: selectedOpeningDimensionKey,
      ),
      transform: transform,
    );
    for (final visual in openingDimensionVisuals) {
      visual.paint(canvas, bundle.unitSystem);
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

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) {
      return;
    }
    final direction = delta / distance;
    const dashLength = 14.0;
    const gapLength = 8.0;
    var offset = 0.0;
    while (offset < distance) {
      final dashStart = start + direction * offset;
      final dashEnd = start + direction * min(offset + dashLength, distance);
      canvas.drawLine(dashStart, dashEnd, paint);
      offset += dashLength + gapLength;
    }
  }

  void _paintExternalBadge({
    required Canvas canvas,
    required Offset anchor,
    required Offset center,
    required RoomEditorAnnotationBadge badge,
  }) {
    final accentColor = badge.color ?? Colors.white;
    final leaderPaint = Paint()
      ..color = _withOpacity(accentColor, 0.85)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(anchor, center, leaderPaint);
    final hitBox = Rect.fromCenter(center: center, width: 26, height: 26);
    final badgeRect = RRect.fromRectAndRadius(hitBox, const Radius.circular(8));
    canvas
      ..drawRRect(badgeRect, Paint()..color = const Color(0xFF101418))
      ..drawRRect(
        badgeRect,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    if (badge.text != null) {
      final painter = TextPainter(
        text: TextSpan(
          text: badge.text,
          style: TextStyle(
            inherit: false,
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w700,
            color: accentColor,
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
      return;
    }
    final icon = badge.icon!;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: 16,
          height: 1,
          color: accentColor,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
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
      oldDelegate.documentConstraintState != documentConstraintState ||
      oldDelegate.constraintVisuals != constraintVisuals ||
      oldDelegate.highlightedConstraintKeys.length !=
          highlightedConstraintKeys.length ||
      oldDelegate.highlightedImplicitLengthLineIndices.length !=
          highlightedImplicitLengthLineIndices.length ||
      !oldDelegate.highlightedImplicitLengthLineIndices.containsAll(
        highlightedImplicitLengthLineIndices,
      ) ||
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
      !mapEquals(oldDelegate.linePresentations, linePresentations) ||
      !mapEquals(
        oldDelegate.intersectionPresentations,
        intersectionPresentations,
      ) ||
      oldDelegate.selectedOpeningIndex != selectedOpeningIndex ||
      oldDelegate.selectedOpeningDimensionKey != selectedOpeningDimensionKey;
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
  final String? label;
  final bool constrained;
  final bool selected;

  const RoomEditorConstraintVisualDebug({
    required this.key,
    required this.kind,
    required this.hitBox,
    required this.anchor,
    this.center,
    this.lineStart,
    this.lineEnd,
    this.label,
    this.constrained = true,
    this.selected = false,
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
  final bool constrained;
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
    this.constrained = true,
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

  bool contains(Offset point) => hitBox.contains(point);

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
              : constrained
              ? const Color(0xFF101418)
              : const Color(0xFF202830),
      )
      ..drawRRect(
        badgeRect,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.0 : 1.2,
      );
    if (badgeText == '||') {
      final parallelPaint = Paint()
        ..color = accentColor
        ..strokeWidth = selected ? 2.3 : 1.9
        ..strokeCap = StrokeCap.round;
      final firstStart = Offset(hitBox.left + 6, hitBox.center.dy + 3.5);
      final firstEnd = Offset(hitBox.right - 5, hitBox.center.dy - 1.5);
      const separation = Offset(0, -6);
      canvas
        ..drawLine(firstStart, firstEnd, parallelPaint)
        ..drawLine(
          firstStart + separation,
          firstEnd + separation,
          parallelPaint,
        );
      return;
    }
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
        : constrained
        ? Colors.white
        : const Color(0xFFB8C0C8);
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
        text: constrained ? '= $label' : label,
        style: TextStyle(
          color: selected
              ? const Color(0xFFFFB84D)
              : constrained
              ? Colors.white
              : const Color(0xFFD2D8DE),
          fontSize: 12,
          fontWeight: constrained ? FontWeight.w700 : FontWeight.w500,
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
  if (lines.isEmpty) {
    return const [];
  }
  final polygonDirection = _polygonDirection(lines);
  final selectedLineIndices = {
    for (final index in selection.selectedLineIndices)
      if (index >= 0 && index < lines.length) index,
  };
  final selectedLineIds = {
    for (final index in selectedLineIndices) lines[index].id,
  };
  final selectedIntersectionIds = {
    for (final index in selection.selectedIntersectionIndices)
      if (index >= 0 && index < lines.length) lines[index].id,
  };

  bool associatedWithSelection(RoomEditorConstraint constraint) {
    if (constraint.type == RoomEditorConstraintType.jointAngle) {
      final jointLineIndex = lines.indexWhere(
        (line) => line.id == constraint.lineId,
      );
      if (jointLineIndex >= 0) {
        final previousLineIndex =
            (jointLineIndex - 1 + lines.length) % lines.length;
        if (selectedLineIndices.contains(jointLineIndex) ||
            selectedLineIndices.contains(previousLineIndex)) {
          return true;
        }
      }
      return selectedIntersectionIds.contains(constraint.lineId);
    }
    return selectedLineIds.contains(constraint.lineId) ||
        selectedLineIds.contains(constraint.targetValue);
  }

  final visibleConstraints = document.constraints.where((constraint) {
    final key = RoomEditorConstraintKey.fromConstraint(constraint);
    if (selection.selectedConstraintKey == key ||
        highlightedKeys.contains(key)) {
      return true;
    }
    return showAllConstraints || associatedWithSelection(constraint);
  });

  final visuals = <_ConstraintVisual>[];
  final baseOffset = transform.worldDistanceForCanvasDistance(68);
  final tangentShiftDistance = transform.worldDistanceForCanvasDistance(24);

  _ConstraintVisual? buildLineLengthVisual({
    required int lineIndex,
    required RoomEditorLine line,
    required RoomEditorConstraintKey key,
    required bool selected,
    required bool attention,
    required bool constrained,
    int? targetValue,
  }) {
    final startWorld = Offset(line.startX.toDouble(), line.startY.toDouble());
    final endPoint = RoomCanvasGeometry.lineEnd(lines, lineIndex);
    final endWorld = Offset(endPoint.x.toDouble(), endPoint.y.toDouble());
    final direction = endWorld - startWorld;
    if (direction.distance == 0) {
      return null;
    }
    final tangent = direction / direction.distance;
    final normal = Offset(-tangent.dy, tangent.dx);
    final outsideNormal = polygonDirection >= 0 ? -normal : normal;
    final offsetWorld = customOffsets[key] ?? outsideNormal * baseOffset;
    final dimensionStartWorld = startWorld + offsetWorld;
    final dimensionEndWorld = endWorld + offsetWorld;
    final dimensionStart = transform.toCanvasOffset(dimensionStartWorld);
    final dimensionEnd = transform.toCanvasOffset(dimensionEndWorld);
    final label = RoomCanvasGeometry.formatDisplayLength(
      targetValue ?? line.length,
      document.bundle.unitSystem,
    );
    final labelPainter = TextPainter(
      text: TextSpan(
        text: constrained ? '= $label' : label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final midpoint = Offset(
      (dimensionStart.dx + dimensionEnd.dx) / 2,
      (dimensionStart.dy + dimensionEnd.dy) / 2,
    );
    final anchorWorld = (startWorld + endWorld) / 2;
    return _ConstraintVisual(
      key: key,
      kind: _ConstraintVisualKind.dimension,
      selected: selected,
      attention: attention,
      anchor: transform.toCanvasOffset(anchorWorld),
      anchorWorld: anchorWorld,
      hitBox: Rect.fromCenter(
        center: midpoint,
        width: labelPainter.width + 18,
        height: labelPainter.height + 10,
      ),
      constrained: constrained,
      lineStart: dimensionStart,
      lineEnd: dimensionEnd,
      extensionStart: dimensionStart,
      extensionEnd: dimensionEnd,
      dimensionAnchorStart: transform.toCanvasOffset(startWorld),
      dimensionAnchorEnd: transform.toCanvasOffset(endWorld),
      dragNormalWorld: outsideNormal,
      label: label,
    );
  }

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
    final selected =
        selection.selectedConstraintKey == key ||
        associatedWithSelection(constraint);
    final attention = highlightedKeys.contains(key);

    switch (constraint.type) {
      case RoomEditorConstraintType.lineLength:
        final visual = buildLineLengthVisual(
          lineIndex: lineIndex,
          line: line,
          key: key,
          selected: selected,
          attention: attention,
          constrained: true,
          targetValue: constraint.targetValue,
        );
        if (visual != null) {
          visuals.add(visual);
        }
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
        final isRightAngle =
            (constraint.targetValue ?? 0) ==
            RoomEditorConstraintSolver.degreesToAngleValue(90);
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
            icon: isRightAngle ? Icons.square_foot : Icons.architecture,
          ),
        );
    }
  }

  final constrainedLengthLineIds = {
    for (final constraint in document.constraints)
      if (constraint.type == RoomEditorConstraintType.lineLength)
        constraint.lineId,
  };
  if (showAllConstraints || selectedLineIndices.isNotEmpty) {
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final key = RoomEditorConstraintKey(
        lineId: line.id,
        type: RoomEditorConstraintType.lineLength,
      );
      final selected = selectedLineIndices.contains(lineIndex);
      if (constrainedLengthLineIds.contains(line.id) ||
          (!showAllConstraints &&
              !selected &&
              !highlightedKeys.contains(key))) {
        continue;
      }
      final visual = buildLineLengthVisual(
        lineIndex: lineIndex,
        line: line,
        key: key,
        selected: selected,
        attention: highlightedKeys.contains(key),
        constrained: false,
      );
      if (visual != null) {
        visuals.add(visual);
      }
    }
  }

  return visuals;
}

class _OpeningDimensionVisual {
  final RoomEditorOpeningDimensionKey key;
  final bool selected;
  final Offset anchorStart;
  final Offset anchorEnd;
  final Offset dimensionStart;
  final Offset dimensionEnd;
  final Rect hitBox;
  final String label;

  const _OpeningDimensionVisual({
    required this.key,
    required this.selected,
    required this.anchorStart,
    required this.anchorEnd,
    required this.dimensionStart,
    required this.dimensionEnd,
    required this.hitBox,
    required this.label,
  });

  bool contains(Offset point) =>
      hitBox.contains(point) ||
      _ConstraintVisual._distanceToSegment(
            point,
            dimensionStart,
            dimensionEnd,
          ) <=
          8 ||
      _ConstraintVisual._distanceToSegment(
            point,
            anchorStart,
            dimensionStart,
          ) <=
          8 ||
      _ConstraintVisual._distanceToSegment(point, anchorEnd, dimensionEnd) <= 8;

  void paint(Canvas canvas, RoomEditorUnitSystem unitSystem) {
    final strokeColor = selected ? Colors.orange : Colors.white;
    final paint = Paint()
      ..color = _withOpacity(strokeColor, 0.92)
      ..strokeWidth = selected ? 2.2 : 1.2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(anchorStart, dimensionStart, paint)
      ..drawLine(anchorEnd, dimensionEnd, paint)
      ..drawLine(dimensionStart, dimensionEnd, paint);
    _paintOpeningDimensionTick(canvas, dimensionStart, dimensionEnd, paint);
    _paintOpeningDimensionTick(canvas, dimensionEnd, dimensionStart, paint);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: selected ? Colors.orange.shade900 : Colors.black,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelRect = RRect.fromRectAndRadius(hitBox, const Radius.circular(6));
    canvas
      ..drawRRect(
        labelRect,
        Paint()
          ..color = _withOpacity(
            selected ? const Color(0xFFFFE2BF) : Colors.white,
            0.96,
          ),
      )
      ..drawRRect(
        labelRect,
        Paint()
          ..color = _withOpacity(strokeColor, 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.6 : 1.0,
      );
    labelPainter.paint(
      canvas,
      Offset(
        hitBox.left + (hitBox.width - labelPainter.width) / 2,
        hitBox.top + (hitBox.height - labelPainter.height) / 2,
      ),
    );
  }
}

void _paintOpeningDimensionTick(
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
  const tickLength = 5.0;
  canvas.drawLine(
    point - unit * tickLength + normal * tickLength,
    point + unit * tickLength - normal * tickLength,
    paint,
  );
}

List<_OpeningDimensionVisual> buildOpeningDimensionVisuals({
  required RoomEditorDocument document,
  required RoomEditorSelection selection,
  required _CanvasTransform transform,
}) {
  final openingIndex = selection.selectedOpeningIndex;
  if (openingIndex == null ||
      openingIndex < 0 ||
      openingIndex >= document.bundle.openings.length) {
    return const [];
  }
  final opening = document.bundle.openings[openingIndex];
  final lines = document.bundle.lines;
  final lineIndex = lines.indexWhere((line) => line.id == opening.lineId);
  if (lineIndex < 0) {
    return const [];
  }
  final line = lines[lineIndex];
  final start = transform.toCanvasPoint(line.startX, line.startY);
  final endPoint = RoomCanvasGeometry.lineEnd(lines, lineIndex);
  final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final segmentLength = sqrt(dx * dx + dy * dy);
  if (segmentLength == 0 || line.length <= 0) {
    return const [];
  }
  final tangent = Offset(dx / segmentLength, dy / segmentLength);
  final normal = Offset(-dy / segmentLength, dx / segmentLength);
  final polygonDirection = _polygonDirection(lines);
  final outsideNormal = polygonDirection >= 0 ? -normal : normal;
  final insideNormal = -outsideNormal;
  final offset = insideNormal * 34;
  final openingStart =
      start +
      tangent * (segmentLength * (opening.offsetFromStart / line.length));
  final openingEnd =
      start +
      tangent *
          (segmentLength *
              ((opening.offsetFromStart + opening.width) / line.length));
  final points = [start, openingStart, openingEnd, end];
  final labels = <(RoomEditorOpeningDimensionKey, String)>[
    (
      RoomEditorOpeningDimensionKey(
        openingId: opening.id,
        type: RoomEditorOpeningDimensionType.distanceToStartWall,
      ),
      RoomCanvasGeometry.formatDisplayLength(
        opening.distanceToStartWall ?? opening.offsetFromStart,
        document.bundle.unitSystem,
      ),
    ),
    (
      RoomEditorOpeningDimensionKey(
        openingId: opening.id,
        type: RoomEditorOpeningDimensionType.width,
      ),
      RoomCanvasGeometry.formatDisplayLength(
        opening.width,
        document.bundle.unitSystem,
      ),
    ),
    (
      RoomEditorOpeningDimensionKey(
        openingId: opening.id,
        type: RoomEditorOpeningDimensionType.distanceToEndWall,
      ),
      RoomCanvasGeometry.formatDisplayLength(
        opening.distanceToEndWall ?? openingDistanceToEndWall(opening, line),
        document.bundle.unitSystem,
      ),
    ),
  ];
  final visuals = <_OpeningDimensionVisual>[];
  for (var index = 0; index < 3; index++) {
    final segmentStart = points[index];
    final segmentEnd = points[index + 1];
    final dimensionStart = segmentStart + offset;
    final dimensionEnd = segmentEnd + offset;
    final midpoint = Offset(
      (dimensionStart.dx + dimensionEnd.dx) / 2,
      (dimensionStart.dy + dimensionEnd.dy) / 2,
    );
    final label = labels[index].$2;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    visuals.add(
      _OpeningDimensionVisual(
        key: labels[index].$1,
        selected: selection.selectedOpeningDimensionKey == labels[index].$1,
        anchorStart: segmentStart,
        anchorEnd: segmentEnd,
        dimensionStart: dimensionStart,
        dimensionEnd: dimensionEnd,
        hitBox: Rect.fromCenter(
          center: midpoint,
          width: painter.width + 12,
          height: painter.height + 8,
        ),
        label: label,
      ),
    );
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
        label: visual.label,
        constrained: visual.constrained,
        selected: visual.selected,
      ),
  ];
}

Rect _computeCanvasPaintBounds({
  required RoomEditorDocument document,
  required RoomEditorSelection selection,
  required bool showAllConstraints,
  required Map<RoomEditorConstraintKey, Offset> customOffsets,
  required Map<int, RoomEditorLinePresentation> linePresentations,
  required Map<int, RoomEditorIntersectionPresentation>
  intersectionPresentations,
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

    final lineBadge = linePresentations[line.id]?.badge;
    if (lineBadge != null) {
      final badgeCenter = mid + outsideNormal * 58;
      includePoint(badgeCenter, radius: 18);
      includeRect(Rect.fromCenter(center: badgeCenter, width: 30, height: 30));
    }

    final intersectionBadge = intersectionPresentations[line.id]?.badge;
    if (intersectionBadge != null) {
      final badgeCenter = start + outsideNormal * 34;
      includePoint(badgeCenter, radius: 18);
      includeRect(Rect.fromCenter(center: badgeCenter, width: 30, height: 30));
    }

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

  _CanvasWorldBounds get worldBounds =>
      _CanvasWorldBounds(minX: _minX, minY: _minY, maxX: _maxX, maxY: _maxY);

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

  double get width => (maxX - minX).abs().toDouble().clamp(1, double.infinity);

  double get height => (maxY - minY).abs().toDouble().clamp(1, double.infinity);

  double zoomRatioFor(_CanvasWorldBounds viewport) {
    final widthRatio = width / viewport.width;
    final heightRatio = height / viewport.height;
    return widthRatio < heightRatio ? widthRatio : heightRatio;
  }

  _CanvasWorldBounds translate(double dx, double dy) => _CanvasWorldBounds(
    minX: (minX + dx).round(),
    minY: (minY + dy).round(),
    maxX: (maxX + dx).round(),
    maxY: (maxY + dy).round(),
  );

  _CanvasWorldBounds zoomed({
    required double zoom,
    required Offset anchor,
    required Offset anchorCanvasPosition,
    required Size size,
  }) {
    final nextWidth = width / zoom;
    final nextHeight = height / zoom;
    final availableWidth = max(
      1,
      size.width - (_CanvasTransform._horizontalPadding * 2),
    );
    final availableHeight = max(
      1,
      size.height - (_CanvasTransform._verticalPadding * 2),
    );
    final nextScale = availableWidth / nextWidth < availableHeight / nextHeight
        ? availableWidth / nextWidth
        : availableHeight / nextHeight;
    final minX =
        anchor.dx -
        ((anchorCanvasPosition.dx - _CanvasTransform._horizontalPadding) /
            nextScale);
    final minY =
        anchor.dy -
        ((anchorCanvasPosition.dy - _CanvasTransform._verticalPadding) /
            nextScale);
    return _CanvasWorldBounds(
      minX: minX.round(),
      minY: minY.round(),
      maxX: (minX + nextWidth).round(),
      maxY: (minY + nextHeight).round(),
    );
  }

  factory _CanvasWorldBounds.fromDocument({
    required RoomEditorDocument document,
    required RoomEditorSelection selection,
    required bool showAllConstraints,
    required Map<RoomEditorConstraintKey, Offset> customOffsets,
    required Map<int, RoomEditorLinePresentation> linePresentations,
    required Map<int, RoomEditorIntersectionPresentation>
    intersectionPresentations,
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
      linePresentations: linePresentations,
      intersectionPresentations: intersectionPresentations,
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
