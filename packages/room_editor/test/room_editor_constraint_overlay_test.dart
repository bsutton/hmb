import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  test('selected line exposes visible constraint overlays', () {
    final visuals = debugDescribeConstraintVisuals(
      document: _document,
      selection: RoomEditorSelection(selectedLineIndex: 3),
      showAllConstraints: false,
      size: const Size(900, 700),
    );

    expect(visuals.where((visual) => visual.key.lineId == 4).length, 2);
    expect(
      visuals.any(
        (visual) => visual.key.lineId == 4 && visual.kind == 'dimension',
      ),
      isTrue,
    );
    for (final visual in visuals) {
      expect(visual.hitBox.center.dx, inInclusiveRange(0, 900));
      expect(visual.hitBox.center.dy, inInclusiveRange(0, 700));
    }
  });

  test(
    'show all constraints exposes every constraint and length as dimension',
    () {
      final visuals = debugDescribeConstraintVisuals(
        document: _document,
        selection: const RoomEditorSelection.empty(),
        showAllConstraints: true,
        size: const Size(900, 700),
      );

      expect(visuals.length, _document.constraints.length);
      expect(
        visuals.where((visual) => visual.kind == 'dimension').length,
        _document.constraints
            .where(
              (constraint) =>
                  constraint.type == RoomEditorConstraintType.lineLength,
            )
            .length,
      );

      final lineFourLength = visuals.firstWhere(
        (visual) =>
            visual.key.lineId == 4 &&
            visual.key.type == RoomEditorConstraintType.lineLength,
      );
      expect(lineFourLength.lineStart, isNotNull);
      expect(lineFourLength.lineEnd, isNotNull);
      expect(
        (lineFourLength.lineStart!.dx - lineFourLength.anchor.dx).abs(),
        greaterThan(10),
      );
      expect(
        (lineFourLength.hitBox.center - _defaultWallLengthLabelCenterForLine(3))
            .distance,
        greaterThan(20),
      );
    },
  );

  testWidgets(
    'center vertical wall remains selectable with all constraints shown',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final selectionController = RoomEditorSelectionController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 900,
              child: RoomEditorWorkspace(
                document: _document,
                editorOnly: true,
                selectionController: selectionController,
                onDocumentCommitted: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final customPaint = find.descendant(
        of: find.byType(RoomEditorCanvas),
        matching: find.byType(CustomPaint),
      );
      expect(customPaint, findsOneWidget);
      final canvasSize = tester.getSize(customPaint);
      final canvasOrigin = tester.getTopLeft(customPaint);
      final tapOffset =
          canvasOrigin +
          _worldToCanvas(
            const Offset(1800, 1800),
            canvasSize,
            _document.bundle.lines,
          );

      await tester.tapAt(tapOffset);
      await tester.pumpAndSettle();

      expect(selectionController.value.selectedLineIndex, 3);
      expect(selectionController.value.selectedIntersectionIndex, isNull);
    },
  );
}

final _document = RoomEditorDocument(
  bundle: buildRoomEditorBundle(
    roomName: 'Debug Room',
    unitSystem: RoomEditorUnitSystem.metric,
    plasterCeiling: true,
    lines: const [
      (
        id: 1,
        seqNo: 1,
        startX: 0,
        startY: 0,
        length: 3600,
        plasterSelected: true,
      ),
      (
        id: 2,
        seqNo: 2,
        startX: 3600,
        startY: 0,
        length: 2400,
        plasterSelected: true,
      ),
      (
        id: 3,
        seqNo: 3,
        startX: 3600,
        startY: 2400,
        length: 1800,
        plasterSelected: true,
      ),
      (
        id: 4,
        seqNo: 4,
        startX: 1800,
        startY: 2400,
        length: 1200,
        plasterSelected: true,
      ),
      (
        id: 5,
        seqNo: 5,
        startX: 1800,
        startY: 1200,
        length: 1800,
        plasterSelected: true,
      ),
      (
        id: 6,
        seqNo: 6,
        startX: 0,
        startY: 1200,
        length: 1200,
        plasterSelected: true,
      ),
    ],
    openings: const [],
  ),
  constraints: const [
    RoomEditorConstraint(lineId: 1, type: RoomEditorConstraintType.horizontal),
    RoomEditorConstraint(
      lineId: 1,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 3600,
    ),
    RoomEditorConstraint(lineId: 2, type: RoomEditorConstraintType.vertical),
    RoomEditorConstraint(
      lineId: 2,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 2400,
    ),
    RoomEditorConstraint(lineId: 3, type: RoomEditorConstraintType.horizontal),
    RoomEditorConstraint(
      lineId: 3,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1800,
    ),
    RoomEditorConstraint(lineId: 4, type: RoomEditorConstraintType.vertical),
    RoomEditorConstraint(
      lineId: 4,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1200,
    ),
    RoomEditorConstraint(lineId: 5, type: RoomEditorConstraintType.horizontal),
    RoomEditorConstraint(
      lineId: 5,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1800,
    ),
    RoomEditorConstraint(lineId: 6, type: RoomEditorConstraintType.vertical),
    RoomEditorConstraint(
      lineId: 6,
      type: RoomEditorConstraintType.lineLength,
      targetValue: 1200,
    ),
    RoomEditorConstraint(
      lineId: 1,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 2,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 3,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 4,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 5,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
    RoomEditorConstraint(
      lineId: 6,
      type: RoomEditorConstraintType.jointAngle,
      targetValue: 90000,
    ),
  ],
);

Offset _worldToCanvas(Offset world, Size size, List<RoomEditorLine> lines) {
  const horizontalPadding = 72.0;
  const verticalPadding = 72.0;

  final xs = lines.map((line) => line.startX).toList()..sort();
  final ys = lines.map((line) => line.startY).toList()..sort();
  final minX = xs.first;
  final maxX = xs.last;
  final minY = ys.first;
  final maxY = ys.last;

  final width = (maxX - minX).abs().toDouble().clamp(1, double.infinity);
  final height = (maxY - minY).abs().toDouble().clamp(1, double.infinity);
  final availableWidth = (size.width - (horizontalPadding * 2)).clamp(
    1,
    double.infinity,
  );
  final availableHeight = (size.height - (verticalPadding * 2)).clamp(
    1,
    double.infinity,
  );
  final scale = availableWidth / width < availableHeight / height
      ? availableWidth / width
      : availableHeight / height;

  return Offset(
    horizontalPadding + (world.dx - minX) * scale,
    verticalPadding + (world.dy - minY) * scale,
  );
}

Offset _defaultWallLengthLabelCenterForLine(int index) {
  final lines = _document.bundle.lines;
  final line = lines[index];
  final end = RoomCanvasGeometry.lineEnd(lines, index);
  final startWorld = Offset(line.startX.toDouble(), line.startY.toDouble());
  final endWorld = Offset(end.x.toDouble(), end.y.toDouble());
  final midpoint = (startWorld + endWorld) / 2;
  final direction = endWorld - startWorld;
  final segmentLength = direction.distance;
  final normal = segmentLength == 0
      ? const Offset(0, -1)
      : Offset(-direction.dy / segmentLength, direction.dx / segmentLength);
  final outsideNormal = _polygonDirection(lines) >= 0 ? -normal : normal;
  return _worldToCanvas(
    midpoint + outsideNormal * 40,
    const Size(900, 700),
    lines,
  );
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
