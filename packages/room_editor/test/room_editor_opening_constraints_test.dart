import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  RoomEditorDocument buildDocument({
    required List<RoomEditorOpeningRecord> openings,
    List<RoomEditorConstraint> constraints = const [],
  }) => RoomEditorDocument(
    bundle: buildRoomEditorBundle(
      roomName: 'Room',
      unitSystem: RoomEditorUnitSystem.metric,
      plasterCeiling: false,
      lines: const [
        (id: 1, seqNo: 1, startX: 0, startY: 0, length: 3600),
        (id: 2, seqNo: 2, startX: 3600, startY: 0, length: 2400),
        (id: 3, seqNo: 3, startX: 3600, startY: 2400, length: 1800),
        (id: 4, seqNo: 4, startX: 1800, startY: 2400, length: 1200),
        (id: 5, seqNo: 5, startX: 1800, startY: 1200, length: 1800),
        (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
      ],
      openings: openings,
    ),
    constraints: constraints,
  );

  test('normalize opening honors distance to start wall', () {
    final document = buildDocument(
      openings: const [
        (
          id: 1,
          lineId: 1,
          type: RoomEditorOpeningType.window,
          offsetFromStart: 1400,
          width: 900,
          height: 1200,
          sillHeight: 900,
          distanceToStartWall: 600,
          distanceToEndWall: null,
        ),
      ],
    );

    final normalized = normalizeRoomEditorOpenings(document);
    expect(normalized.bundle.openings.single.offsetFromStart, 600);
  });

  test('normalize opening honors distance to end wall', () {
    final document = buildDocument(
      openings: const [
        (
          id: 1,
          lineId: 1,
          type: RoomEditorOpeningType.door,
          offsetFromStart: 200,
          width: 820,
          height: 2040,
          sillHeight: 0,
          distanceToStartWall: null,
          distanceToEndWall: 480,
        ),
      ],
    );

    final normalized = normalizeRoomEditorOpenings(document);
    expect(normalized.bundle.openings.single.offsetFromStart, 2300);
  });

  test('effective constraints derive wall length from opening dimensions', () {
    final document = buildDocument(
      openings: const [
        (
          id: 1,
          lineId: 1,
          type: RoomEditorOpeningType.window,
          offsetFromStart: 750,
          width: 1200,
          height: 1200,
          sillHeight: 900,
          distanceToStartWall: 750,
          distanceToEndWall: 1650,
        ),
      ],
    );

    final constraints = effectiveRoomEditorConstraints(document);
    final derived = constraints.singleWhere(
      (constraint) =>
          constraint.lineId == 1 &&
          constraint.type == RoomEditorConstraintType.lineLength,
    );
    expect(derived.targetValue, 3600);
  });

  test(
    'opening edge distances can fully constrain a wall length indirectly',
    () {
      final document = buildDocument(
        openings: const [
          (
            id: 1,
            lineId: 1,
            type: RoomEditorOpeningType.window,
            offsetFromStart: 900,
            width: 1200,
            height: 1200,
            sillHeight: 900,
            distanceToStartWall: 900,
            distanceToEndWall: 1500,
          ),
        ],
        constraints: const [
          RoomEditorConstraint(
            lineId: 1,
            type: RoomEditorConstraintType.horizontal,
          ),
          RoomEditorConstraint(
            lineId: 2,
            type: RoomEditorConstraintType.vertical,
          ),
          RoomEditorConstraint(
            lineId: 3,
            type: RoomEditorConstraintType.horizontal,
          ),
          RoomEditorConstraint(
            lineId: 2,
            type: RoomEditorConstraintType.lineLength,
            targetValue: 2400,
          ),
          RoomEditorConstraint(
            lineId: 3,
            type: RoomEditorConstraintType.lineLength,
            targetValue: 1800,
          ),
          RoomEditorConstraint(
            lineId: 4,
            type: RoomEditorConstraintType.vertical,
          ),
          RoomEditorConstraint(
            lineId: 4,
            type: RoomEditorConstraintType.lineLength,
            targetValue: 1200,
          ),
          RoomEditorConstraint(
            lineId: 5,
            type: RoomEditorConstraintType.horizontal,
          ),
          RoomEditorConstraint(
            lineId: 5,
            type: RoomEditorConstraintType.lineLength,
            targetValue: 1800,
          ),
          RoomEditorConstraint(
            lineId: 6,
            type: RoomEditorConstraintType.vertical,
          ),
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

      expect(
        deriveRoomEditorDocumentConstraintState(document),
        RoomEditorDocumentConstraintState.fullyConstrained,
      );
    },
  );
}
