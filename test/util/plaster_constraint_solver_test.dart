import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/plaster_constraint_solver.dart';
import 'package:hmb/util/dart/plaster_geometry.dart';

void main() {
  group('PlasterConstraintSolver', () {
    List<PlasterRoomLine> seededLines() {
      final lines = PlasterGeometry.defaultLines(
        roomId: 1,
        unitSystem: PreferredUnitSystem.metric,
      );
      for (var i = 0; i < lines.length; i++) {
        lines[i].id = i + 1;
      }
      return lines;
    }

    test('solves a line length constraint', () {
      final lines = seededLines();
      final moved = PlasterGeometry.setLength(lines, 0, 45000);
      final constraints = [
        PlasterRoomConstraint.forInsert(
          roomId: 1,
          lineId: moved[0].id,
          type: PlasterConstraintType.lineLength,
          targetValue: 45000,
        ),
      ];

      final result = PlasterConstraintSolver.solve(
        lines: moved,
        constraints: constraints,
      );

      expect(result.converged, isTrue);
      expect(result.lines[0].length, closeTo(45000, 2));
    });

    test('solves a horizontal constraint', () {
      final lines = seededLines();
      final skewed = PlasterGeometry.moveIntersection(
        lines,
        1,
        const IntPoint(30000, 3500),
      );
      final constraints = [
        PlasterRoomConstraint.forInsert(
          roomId: 1,
          lineId: skewed[0].id,
          type: PlasterConstraintType.horizontal,
        ),
      ];

      final result = PlasterConstraintSolver.solve(
        lines: skewed,
        constraints: constraints,
      );

      expect(result.converged, isTrue);
      expect(result.lines[0].startY, closeTo(result.lines[1].startY, 2));
    });

    test('solves a vertical constraint', () {
      final lines = seededLines();
      final skewed = PlasterGeometry.moveIntersection(
        lines,
        1,
        const IntPoint(32500, 0),
      );
      final constraints = [
        PlasterRoomConstraint.forInsert(
          roomId: 1,
          lineId: skewed[1].id,
          type: PlasterConstraintType.vertical,
        ),
      ];

      final result = PlasterConstraintSolver.solve(
        lines: skewed,
        constraints: constraints,
      );

      expect(result.converged, isTrue);
      expect(result.lines[1].startX, closeTo(result.lines[2].startX, 2));
    });

    test('solves a joint angle constraint', () {
      final lines = seededLines();
      final skewed = PlasterGeometry.moveIntersection(
        lines,
        1,
        const IntPoint(35000, 5000),
      );
      final constraints = [
        PlasterRoomConstraint.forInsert(
          roomId: 1,
          lineId: skewed[1].id,
          type: PlasterConstraintType.jointAngle,
          targetValue: PlasterConstraintSolver.degreesToAngleValue(90),
        ),
      ];

      final result = PlasterConstraintSolver.solve(
        lines: skewed,
        constraints: constraints,
      );

      expect(result.converged, isTrue);
      expect(
        PlasterConstraintSolver.currentAngleValue(result.lines, 1),
        closeTo(PlasterConstraintSolver.degreesToAngleValue(90), 50),
      );
    });

    test(
      'projected endpoint-pinned horizontal solve succeeds for toolbar case',
      () {
        final lines = [
          PlasterRoomLine.forInsert(
            roomId: 1,
            seqNo: 0,
            startX: 0,
            startY: 0,
            length: 130000,
          )..id = 1,
          PlasterRoomLine.forInsert(
            roomId: 1,
            seqNo: 1,
            startX: 130000,
            startY: 0,
            length: 23000,
          )..id = 2,
          PlasterRoomLine.forInsert(
            roomId: 1,
            seqNo: 2,
            startX: 116200,
            startY: 18400,
            length: 25000,
          )..id = 3,
          PlasterRoomLine.forInsert(
            roomId: 1,
            seqNo: 3,
            startX: 116200,
            startY: 43400,
            length: 32000,
          )..id = 4,
          PlasterRoomLine.forInsert(
            roomId: 1,
            seqNo: 4,
            startX: 84200,
            startY: 43400,
            length: 78000,
          )..id = 5,
          PlasterRoomLine.forInsert(
            roomId: 1,
            seqNo: 5,
            startX: 6200,
            startY: 43400,
            length: 43841,
          )..id = 6,
        ];

        final constraints = [
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 1,
            type: PlasterConstraintType.lineLength,
            targetValue: 130000,
          ),
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 2,
            type: PlasterConstraintType.lineLength,
            targetValue: 23000,
          ),
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 2,
            type: PlasterConstraintType.horizontal,
          ),
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 3,
            type: PlasterConstraintType.vertical,
          ),
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 4,
            type: PlasterConstraintType.horizontal,
          ),
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 5,
            type: PlasterConstraintType.lineLength,
            targetValue: 78000,
          ),
          PlasterRoomConstraint.forInsert(
            roomId: 1,
            lineId: 5,
            type: PlasterConstraintType.horizontal,
          ),
        ];

        final projected = List<PlasterRoomLine>.from(lines);
        projected[2] = projected[2].copyWith(startY: lines[1].startY);
        final pinnedSolve = PlasterConstraintSolver.solve(
          lines: projected,
          constraints: constraints,
          pinnedVertexIndex: 1,
          pinnedVertexTarget: const IntPoint(130000, 0),
        );
        expect(pinnedSolve.converged, isTrue);
        expect(
          pinnedSolve.lines[1].startY,
          closeTo(PlasterGeometry.lineEnd(pinnedSolve.lines, 1).y, 1),
        );
      },
    );
  });
}
