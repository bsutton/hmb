import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  testWidgets('room canvas enables pinch zoom', (tester) async {
    final document = RoomEditorDocument(
      bundle: buildRoomEditorBundle(
        roomName: 'Zoom',
        unitSystem: RoomEditorUnitSystem.metric,
        plasterCeiling: true,
        lines: const [
          (id: 1, seqNo: 1, startX: 0, startY: 0, length: 3000),
          (id: 2, seqNo: 2, startX: 3000, startY: 0, length: 2400),
          (id: 3, seqNo: 3, startX: 3000, startY: 2400, length: 3000),
          (id: 4, seqNo: 4, startX: 0, startY: 2400, length: 2400),
        ],
        openings: const [],
      ),
      constraints: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 320,
            child: RoomEditorCanvas(
              document: document,
              selectionMode: false,
              snapToGrid: false,
              showGrid: false,
              showAllConstraints: false,
              documentConstraintState: deriveRoomEditorDocumentConstraintState(
                document,
              ),
              constraintVisualOffsets: const {},
              wallLabelOffsets: const {},
              highlightedConstraintKeys: const {},
              highlightedImplicitLengthLineIndices: const {},
              linePresentations: const {},
              intersectionPresentations: const {},
              fitRequestId: 0,
              selection: const RoomEditorSelection.empty(),
              callbacks: _callbacks(),
            ),
          ),
        ),
      ),
    );

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );

    expect(viewer.scaleEnabled, isTrue);
    expect(viewer.maxScale, greaterThan(1));
  });
}

RoomEditorCanvasCallbacks _callbacks() => RoomEditorCanvasCallbacks(
  onStartMoveIntersection: () {},
  onMoveIntersection: (_, _) {},
  onEndMoveIntersection: () async {},
  onStartMoveLine: () {},
  onMoveLine: (_, _) {},
  onEndMoveLine: () async {},
  onStartMoveOpening: () {},
  onMoveOpening: (_, _, _) {},
  onEndMoveOpening: () async {},
  onTapIntersection: (_) async {},
  onTapOpening: (_) async {},
  onTapLine: (_) async {},
  onTapCeiling: () async {},
  onTapConstraint: (_) async {},
  onTapOpeningDimension: (_) async {},
  onMoveConstraint: (_, _) {},
  onMoveWallLabel: (_, _) {},
  onDeleteConstraint: (_) async {},
);
