import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'room_canvas_geometry.dart';
import 'room_canvas_models.dart';

class RoomEditorCanvas extends StatefulWidget {
  final RoomEditorBundle bundle;
  final bool selectionMode;
  final bool snapToGrid;
  final bool showGrid;
  final int fitRequestId;
  final RoomEditorSelection selection;
  final RoomEditorCanvasCallbacks callbacks;
  final double height;

  const RoomEditorCanvas({
    super.key,
    required this.bundle,
    required this.selectionMode,
    required this.snapToGrid,
    required this.showGrid,
    required this.fitRequestId,
    required this.selection,
    required this.callbacks,
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
  int? _dragIndex;
  int? _dragOpeningIndex;
  var _dragOpeningAnchorOffset = 0;
  int? _pendingDragIndex;
  int? _pendingDragOpeningIndex;
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
  void dispose() {
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
      _dragIndex != null || _dragOpeningIndex != null;

  void _cancelGeometryDrag() {
    final draggingOpening = _dragOpeningIndex != null;
    final draggingIntersection = _dragIndex != null;

    _dragOpeningIndex = null;
    _dragOpeningAnchorOffset = 0;
    _dragIndex = null;
    _clearPendingGesture();

    if (draggingOpening || draggingIntersection) {
      setState(() {});
      if (draggingOpening) {
        unawaited(widget.callbacks.onEndMoveOpening());
      } else {
        unawaited(widget.callbacks.onEndMoveIntersection());
      }
    }
  }

  void _clearPendingGesture() {
    _pendingDragIndex = null;
    _pendingDragOpeningIndex = null;
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
    _pendingDragOpeningIndex = transform.hitOpening(
      widget.bundle.openings,
      canvasPosition,
    );
    if (_pendingDragOpeningIndex != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= _CanvasWorldBounds.fromLines(widget.bundle.lines);
      _pendingDragOpeningAnchorOffset = transform.openingDragAnchorOffset(
        widget.bundle.openings,
        canvasPosition,
        _pendingDragOpeningIndex!,
      );
      _pendingDragIndex = null;
      return;
    }

    _pendingDragIndex = transform.hitIntersection(canvasPosition);
    if (_pendingDragIndex != null) {
      _dragTransform = transform;
      _dragViewportBounds ??= _CanvasWorldBounds.fromLines(widget.bundle.lines);
    }
  }

  void _handlePointerMove(PointerMoveEvent event, _CanvasTransform transform) {
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
    if (_dragOpeningIndex != null) {
      widget.callbacks.onMoveOpening(
        _dragOpeningIndex!,
        dragTransform.toWorld(canvasPosition),
        _dragOpeningAnchorOffset,
      );
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

    _dragOpeningIndex = null;
    _dragOpeningAnchorOffset = 0;
    _dragIndex = null;
    _clearPendingGesture();

    if (draggingOpening || draggingIntersection) {
      setState(() {});
      if (draggingOpening) {
        unawaited(widget.callbacks.onEndMoveOpening());
      } else {
        unawaited(widget.callbacks.onEndMoveIntersection());
      }
    }
  }

  Future<void> _handleTapSelection(
    BuildContext context,
    Offset localPosition,
    _CanvasTransform transform,
  ) async {
    final openingIndex = transform.hitOpening(
      widget.bundle.openings,
      localPosition,
    );
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
      if (transform.hitPolygon(localPosition)) {
        await widget.callbacks.onTapCeiling();
      }
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final resolvedHeight =
          constraints.hasBoundedHeight && constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : widget.height;
      final size = Size(constraints.maxWidth, resolvedHeight);
      if (widget.bundle.lines.isEmpty) {
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
          _CanvasWorldBounds.fromLines(widget.bundle.lines);
      final transform = _CanvasTransform(
        widget.bundle.lines,
        size,
        bounds: viewportBounds,
      );
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
                bundle: widget.bundle,
                transform: transform,
                selectionMode: widget.selectionMode,
                showGrid: widget.showGrid,
                selectedLineIndex: widget.selection.selectedLineIndex,
                selectedIntersectionIndex:
                    widget.selection.selectedIntersectionIndex,
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
  final RoomEditorBundle bundle;
  final _CanvasTransform transform;
  final bool selectionMode;
  final bool showGrid;
  final int? selectedLineIndex;
  final int? selectedIntersectionIndex;
  final int? selectedOpeningIndex;

  const _RoomPainter({
    required this.bundle,
    required this.transform,
    required this.selectionMode,
    required this.showGrid,
    required this.selectedLineIndex,
    required this.selectedIntersectionIndex,
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

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final start = transform.toCanvasPoint(line.startX, line.startY);
      final endPoint = RoomCanvasGeometry.lineEnd(lines, i);
      final end = transform.toCanvasPoint(endPoint.x, endPoint.y);
      final isSelected = selectedLineIndex == i;
      final isSelectedIntersection = selectedIntersectionIndex == i;
      final paint = Paint()
        ..color = isSelected
            ? Colors.orange
            : (line.plasterSelected ? Colors.blue : Colors.grey)
        ..strokeWidth = isSelected ? 5 : 3;
      final vertexColor = isSelectedIntersection
          ? Colors.redAccent
          : (isSelected
                ? Colors.orange
                : (line.plasterSelected ? Colors.blue : Colors.grey));
      canvas
        ..drawLine(start, end, paint)
        ..drawCircle(
          start,
          isSelected || isSelectedIntersection ? 7 : 6,
          Paint()..color = vertexColor,
        );
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
      oldDelegate.bundle != bundle ||
      oldDelegate.selectionMode != selectionMode ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.selectedLineIndex != selectedLineIndex ||
      oldDelegate.selectedIntersectionIndex != selectedIntersectionIndex ||
      oldDelegate.selectedOpeningIndex != selectedOpeningIndex;
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

  double canvasXForWorldX(int x) => _offsetX + (x - _minX) * _scale;

  double canvasYForWorldY(int y) => _offsetY + (y - _minY) * _scale;

  RoomEditorIntPoint toWorld(Offset offset) => RoomEditorIntPoint(
    _minX + ((offset.dx - _offsetX) / _scale).round(),
    _minY + ((offset.dy - _offsetY) / _scale).round(),
  );

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
