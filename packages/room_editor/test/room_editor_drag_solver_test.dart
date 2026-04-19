import 'package:flutter_test/flutter_test.dart';
import 'package:room_editor/room_editor.dart';
import 'package:room_editor/src/room_editor_drag_solver.dart';

void main() {
  test(
    'rigid orthogonal systems clamp impossible drags to current document',
    () {
      final document = RoomEditorDocument(
        bundle: buildRoomEditorBundle(
          roomName: 'Rigid',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: true,
          lines: const [
            (id: 1, seqNo: 1, startX: 0, startY: 0, length: 3600),
            (id: 2, seqNo: 2, startX: 3600, startY: 0, length: 2400),
            (id: 3, seqNo: 3, startX: 3600, startY: 2400, length: 1800),
            (id: 4, seqNo: 4, startX: 1800, startY: 2400, length: 1200),
            (id: 5, seqNo: 5, startX: 1800, startY: 1200, length: 1800),
            (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
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

      final result = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: document,
          gestureBaseDocument: document,
          movedIndex: 2,
          movedTarget: const RoomEditorIntPoint(4000, 2000),
          emitDistanceThreshold: 100,
        ),
      );

      expect(result.rigidConstraintClamp, isTrue);
      expect(result.solvedDocument, same(document));
      expect(result.solvedDocument!.bundle.lines[2].startX, 3600);
      expect(result.solvedDocument!.bundle.lines[2].startY, 2400);
    },
  );

  test(
    'dragging a vertex respects incoming vertical constraint and still moves',
    () {
      final document = RoomEditorDocument(
        bundle: buildRoomEditorBundle(
          roomName: 'Projected drag',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: true,
          lines: const [
            (id: 1, seqNo: 1, startX: 0, startY: 0, length: 3600),
            (id: 2, seqNo: 2, startX: 3600, startY: 0, length: 2400),
            (id: 3, seqNo: 3, startX: 3600, startY: 2400, length: 1800),
            (id: 4, seqNo: 4, startX: 1800, startY: 2400, length: 1200),
            (id: 5, seqNo: 5, startX: 1800, startY: 1200, length: 1800),
            (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
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

      final result = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: document,
          gestureBaseDocument: document,
          movedIndex: 2,
          movedTarget: const RoomEditorIntPoint(4000, 3000),
          emitDistanceThreshold: 100,
        ),
      );

      expect(result.rigidConstraintClamp, isFalse);
      expect(result.solvedDocument, isNotNull);
      expect(result.solvedDocument!.bundle.lines[2].startX, 3600);
      expect(result.solvedDocument!.bundle.lines[2].startY, 3000);
      expect(result.solvedDocument!.bundle.lines[3].startY, 3000);
    },
  );

  test(
    '''
dragging a vertex can move horizontally when incoming line is vertical with fixed length''',
    () {
      final document = RoomEditorDocument(
        bundle: buildRoomEditorBundle(
          roomName: 'Horizontal move',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: true,
          lines: const [
            (id: 1, seqNo: 1, startX: 0, startY: -1, length: 3600),
            (id: 2, seqNo: 2, startX: 3600, startY: -2, length: 2230),
            (id: 3, seqNo: 3, startX: 3600, startY: 2228, length: 1800),
            (id: 4, seqNo: 4, startX: 1800, startY: 2228, length: 1029),
            (id: 5, seqNo: 5, startX: 1800, startY: 1199, length: 1800),
            (id: 6, seqNo: 6, startX: 0, startY: 1199, length: 1200),
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
          RoomEditorConstraint(
            lineId: 2,
            type: RoomEditorConstraintType.lineLength,
            targetValue: 2230,
          ),
        ],
      );

      final result = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: document,
          gestureBaseDocument: document,
          movedIndex: 2,
          movedTarget: const RoomEditorIntPoint(3535, 2055),
          emitDistanceThreshold: 100,
        ),
      );

      expect(result.rigidConstraintClamp, isFalse);
      expect(result.solvedDocument, isNotNull);
      expect(result.solvedDocument!.bundle.lines[2].startX, 3535);
      expect(result.solvedDocument!.bundle.lines[2].startY, 2228);
      expect(result.solvedDocument!.bundle.lines[1].startX, 3535);
      expect(result.solvedDocument!.bundle.lines[1].startY, -2);
    },
  );

  test(
    '''dragging a vertex can move horizontally when incoming line is only vertical''',
    () {
      final document = RoomEditorDocument(
        bundle: buildRoomEditorBundle(
          roomName: 'Horizontal move without fixed length',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: true,
          lines: const [
            (id: 1, seqNo: 1, startX: 0, startY: 0, length: 2251),
            (id: 2, seqNo: 2, startX: 2251, startY: 0, length: 2401),
            (id: 3, seqNo: 3, startX: 2251, startY: 2401, length: 451),
            (id: 4, seqNo: 4, startX: 1800, startY: 2401, length: 1201),
            (id: 5, seqNo: 5, startX: 1800, startY: 1200, length: 1800),
            (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
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

      final result = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: document,
          gestureBaseDocument: document,
          movedIndex: 2,
          movedTarget: const RoomEditorIntPoint(2292, 2401),
          emitDistanceThreshold: 100,
        ),
      );

      expect(result.rigidConstraintClamp, isFalse);
      expect(result.solvedDocument, isNotNull);
      expect(result.solvedDocument!.bundle.lines[2].startX, 2292);
      expect(result.solvedDocument!.bundle.lines[2].startY, 2401);
      expect(result.solvedDocument!.bundle.lines[1].startX, 2292);
      expect(result.solvedDocument!.bundle.lines[1].startY, 0);
    },
  );

  test(
    '''dragging a vertex can move horizontally when outgoing line is horizontal with downstream fixed support''',
    () {
      final document = RoomEditorDocument(
        bundle: buildRoomEditorBundle(
          roomName: 'Outgoing horizontal support',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: true,
          lines: const [
            (id: 1, seqNo: 1, startX: 0, startY: 0, length: 2681),
            (id: 2, seqNo: 2, startX: 2681, startY: 0, length: 1662),
            (id: 3, seqNo: 3, startX: 2453, startY: 1646, length: 988),
            (id: 4, seqNo: 4, startX: 1465, startY: 1646, length: 445),
            (id: 5, seqNo: 5, startX: 1465, startY: 1201, length: 1465),
            (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
          ],
          openings: const [],
        ),
        constraints: const [
          RoomEditorConstraint(
            lineId: 1,
            type: RoomEditorConstraintType.horizontal,
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

      final result = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: document,
          gestureBaseDocument: document,
          movedIndex: 4,
          movedTarget: const RoomEditorIntPoint(1419, 1197),
          emitDistanceThreshold: 100,
        ),
      );

      expect(result.solvedDocument, isNotNull);
      expect(result.solvedDocument!.bundle.lines[4].startX, 1419);
      expect(result.solvedDocument!.bundle.lines[4].startY, 1201);
      expect(result.solvedDocument!.bundle.lines[3].startX, 1419);
      expect(result.solvedDocument!.bundle.lines[3].startY, 1646);
    },
  );

  test(
    '''dragging the W4/W5 corner can move vertically with W4 fixed length''',
    () {
      final document = RoomEditorDocument(
        bundle: buildRoomEditorBundle(
          roomName: 'Vertical notch drag',
          unitSystem: RoomEditorUnitSystem.metric,
          plasterCeiling: true,
          lines: const [
            (id: 1, seqNo: 1, startX: 0, startY: 0, length: 3600),
            (id: 2, seqNo: 2, startX: 3600, startY: 0, length: 2400),
            (id: 3, seqNo: 3, startX: 3600, startY: 2400, length: 1905),
            (id: 4, seqNo: 4, startX: 1695, startY: 2400, length: 1200),
            (id: 5, seqNo: 5, startX: 1695, startY: 1200, length: 1695),
            (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
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
            lineId: 4,
            type: RoomEditorConstraintType.lineLength,
            targetValue: 1200,
          ),
          RoomEditorConstraint(
            lineId: 5,
            type: RoomEditorConstraintType.horizontal,
          ),
          RoomEditorConstraint(
            lineId: 6,
            type: RoomEditorConstraintType.vertical,
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

      final result = RoomEditorDragSolver.solve(
        RoomEditorDragSolveRequest(
          currentDocument: document,
          gestureBaseDocument: document,
          movedIndex: 4,
          movedTarget: const RoomEditorIntPoint(1695, 1100),
          emitDistanceThreshold: 100,
        ),
      );

      expect(result.rigidConstraintClamp, isFalse);
      expect(result.solvedDocument, isNotNull);
      expect(result.solvedDocument!.bundle.lines[4].startX, 1695);
      expect(result.solvedDocument!.bundle.lines[4].startY, 1100);
      expect(result.solvedDocument!.bundle.lines[3].startX, 1695);
      expect(result.solvedDocument!.bundle.lines[3].startY, 2300);
    },
  );

  test('dragging a fixed vertical notch can continue with diagonal drift', () {
    final document = RoomEditorDocument(
      bundle: buildRoomEditorBundle(
        roomName: 'Diagonal notch drag',
        unitSystem: RoomEditorUnitSystem.metric,
        plasterCeiling: true,
        lines: const [
          (id: 1, seqNo: 1, startX: 0, startY: 0, length: 3703),
          (id: 2, seqNo: 2, startX: 3703, startY: 0, length: 2400),
          (id: 3, seqNo: 3, startX: 3703, startY: 2400, length: 1622),
          (id: 4, seqNo: 4, startX: 2081, startY: 2400, length: 1200),
          (id: 5, seqNo: 5, startX: 2081, startY: 1200, length: 2081),
          (id: 6, seqNo: 6, startX: 0, startY: 1200, length: 1200),
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
          lineId: 4,
          type: RoomEditorConstraintType.lineLength,
          targetValue: 1200,
        ),
        RoomEditorConstraint(
          lineId: 5,
          type: RoomEditorConstraintType.horizontal,
        ),
        RoomEditorConstraint(
          lineId: 6,
          type: RoomEditorConstraintType.vertical,
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

    final first = RoomEditorDragSolver.solve(
      RoomEditorDragSolveRequest(
        currentDocument: document,
        gestureBaseDocument: document,
        movedIndex: 4,
        movedTarget: const RoomEditorIntPoint(1781, 1034),
        emitDistanceThreshold: 100,
      ),
    );
    expect(first.solvedDocument, isNotNull);

    final second = RoomEditorDragSolver.solve(
      RoomEditorDragSolveRequest(
        currentDocument: first.solvedDocument!,
        gestureBaseDocument: document,
        movedIndex: 4,
        movedTarget: const RoomEditorIntPoint(1747, 1034),
        emitDistanceThreshold: 100,
      ),
    );

    expect(second.rigidConstraintClamp, isFalse);
    expect(second.solvedDocument, isNotNull);
    expect(second.solvedDocument!.bundle.lines[4].startX, 1747);
    expect(second.solvedDocument!.bundle.lines[4].startY, 1034);
    expect(second.solvedDocument!.bundle.lines[3].startX, 1747);
    expect(second.solvedDocument!.bundle.lines[3].startY, 2234);
  });
}
