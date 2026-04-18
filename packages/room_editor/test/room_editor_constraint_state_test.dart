import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';

void main() {
  test('redundant orthogonal room remains fully constrained', () {
    final document = RoomEditorDocument(
      bundle: buildRoomEditorBundle(
        roomName: 'Rigid',
        unitSystem: RoomEditorUnitSystem.metric,
        plasterCeiling: true,
        lines: const [
          (
            id: 1,
            seqNo: 1,
            startX: 0,
            startY: 0,
            length: 3600
          ),
          (
            id: 2,
            seqNo: 2,
            startX: 3600,
            startY: 0,
            length: 2400
          ),
          (
            id: 3,
            seqNo: 3,
            startX: 3600,
            startY: 2400,
            length: 1800
          ),
          (
            id: 4,
            seqNo: 4,
            startX: 1800,
            startY: 2400,
            length: 1200
          ),
          (
            id: 5,
            seqNo: 5,
            startX: 1800,
            startY: 1200,
            length: 1800
          ),
          (
            id: 6,
            seqNo: 6,
            startX: 0,
            startY: 1200,
            length: 1200
          ),
        ],
        openings: const [],
      ),
      constraints: const [
        RoomEditorConstraint(
          lineId: 1,
          type: RoomEditorConstraintType.horizontal,
        ),
        RoomEditorConstraint(
          lineId: 1,
          type: RoomEditorConstraintType.lineLength,
          targetValue: 3600,
        ),
        RoomEditorConstraint(
          lineId: 2,
          type: RoomEditorConstraintType.vertical,
        ),
        RoomEditorConstraint(
          lineId: 2,
          type: RoomEditorConstraintType.lineLength,
          targetValue: 2400,
        ),
        RoomEditorConstraint(
          lineId: 3,
          type: RoomEditorConstraintType.horizontal,
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
  });

  test('axis-only room remains under constrained', () {
    final document = RoomEditorDocument(
      bundle: buildRoomEditorBundle(
        roomName: 'Loose',
        unitSystem: RoomEditorUnitSystem.metric,
        plasterCeiling: true,
        lines: const [
          (
            id: 1,
            seqNo: 1,
            startX: 0,
            startY: 0,
            length: 3600
          ),
          (
            id: 2,
            seqNo: 2,
            startX: 3600,
            startY: 0,
            length: 2400
          ),
          (
            id: 3,
            seqNo: 3,
            startX: 3600,
            startY: 2400,
            length: 1800
          ),
          (
            id: 4,
            seqNo: 4,
            startX: 1800,
            startY: 2400,
            length: 1200
          ),
          (
            id: 5,
            seqNo: 5,
            startX: 1800,
            startY: 1200,
            length: 1800
          ),
          (
            id: 6,
            seqNo: 6,
            startX: 0,
            startY: 1200,
            length: 1200
          ),
        ],
        openings: const [],
      ),
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
          lineId: 4,
          type: RoomEditorConstraintType.vertical,
        ),
        RoomEditorConstraint(
          lineId: 5,
          type: RoomEditorConstraintType.horizontal,
        ),
        RoomEditorConstraint(
          lineId: 6,
          type: RoomEditorConstraintType.vertical,
        ),
      ],
    );

    expect(
      deriveRoomEditorDocumentConstraintState(document),
      RoomEditorDocumentConstraintState.underConstrained,
    );
  });

  test('violated geometry is invalid', () {
    final document = RoomEditorDocument(
      bundle: buildRoomEditorBundle(
        roomName: 'Invalid',
        unitSystem: RoomEditorUnitSystem.metric,
        plasterCeiling: true,
        lines: const [
          (
            id: 1,
            seqNo: 1,
            startX: 0,
            startY: 0,
            length: 4000
          ),
          (
            id: 2,
            seqNo: 2,
            startX: 4000,
            startY: 0,
            length: 2400
          ),
          (
            id: 3,
            seqNo: 3,
            startX: 4000,
            startY: 2400,
            length: 4000
          ),
          (
            id: 4,
            seqNo: 4,
            startX: 0,
            startY: 2400,
            length: 2400
          ),
        ],
        openings: const [],
      ),
      constraints: const [
        RoomEditorConstraint(
          lineId: 1,
          type: RoomEditorConstraintType.horizontal,
        ),
        RoomEditorConstraint(
          lineId: 1,
          type: RoomEditorConstraintType.lineLength,
          targetValue: 3600,
        ),
      ],
    );

    expect(
      deriveRoomEditorDocumentConstraintState(document),
      RoomEditorDocumentConstraintState.invalid,
    );
  });
}
