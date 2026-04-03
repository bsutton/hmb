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

    List<PlasterRoomLine> dumpLines() => [
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 0,
        startX: -1895,
        startY: 109631,
        length: 130000,
      )..id = 1,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 1,
        startX: 128105,
        startY: 109631,
        length: 23000,
      )..id = 2,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 2,
        startX: 124000,
        startY: 87000,
        length: 16974,
      )..id = 3,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 3,
        startX: 108000,
        startY: 81333,
        length: 25000,
      )..id = 8,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 4,
        startX: 108000,
        startY: 56333,
        length: 32000,
      )..id = 7,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 5,
        startX: 76000,
        startY: 56333,
        length: 2526,
      )..id = 6,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 6,
        startX: 76105,
        startY: 58857,
        length: 78000,
      )..id = 5,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 7,
        startX: -1895,
        startY: 58857,
        length: 50774,
      )..id = 4,
    ];

    List<PlasterRoomConstraint> dumpConstraints() => [
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 1,
        type: PlasterConstraintType.horizontal,
      ),
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
        lineId: 4,
        type: PlasterConstraintType.vertical,
      ),
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 5,
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
        lineId: 7,
        type: PlasterConstraintType.horizontal,
      ),
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 8,
        type: PlasterConstraintType.vertical,
      ),
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 8,
        type: PlasterConstraintType.lineLength,
        targetValue: 25000,
      ),
    ];

    List<PlasterRoomLine> latestDumpLines() => [
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 0,
        startX: -1519,
        startY: 112068,
        length: 130000,
      )..id = 1,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 1,
        startX: 128481,
        startY: 112068,
        length: 23000,
      )..id = 2,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 2,
        startX: 122000,
        startY: 90000,
        length: 26926,
      )..id = 3,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 3,
        startX: 108000,
        startY: 67000,
        length: 25000,
      )..id = 8,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 4,
        startX: 108000,
        startY: 42000,
        length: 37000,
      )..id = 7,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 5,
        startX: 71000,
        startY: 42000,
        length: 17726,
      )..id = 6,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 6,
        startX: 76481,
        startY: 58857,
        length: 78000,
        plasterSelected: false,
      )..id = 5,
      PlasterRoomLine.forInsert(
        roomId: 1,
        seqNo: 7,
        startX: -1519,
        startY: 58857,
        length: 53211,
        plasterSelected: false,
      )..id = 4,
    ];

    List<PlasterRoomConstraint> latestDumpConstraints() => [
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 1,
        type: PlasterConstraintType.horizontal,
      ),
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
        lineId: 4,
        type: PlasterConstraintType.vertical,
      ),
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 5,
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
        lineId: 7,
        type: PlasterConstraintType.horizontal,
      ),
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 8,
        type: PlasterConstraintType.vertical,
      ),
      PlasterRoomConstraint.forInsert(
        roomId: 1,
        lineId: 8,
        type: PlasterConstraintType.lineLength,
        targetValue: 25000,
      ),
    ];

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

    test('projected endpoint-pinned horizontal solve succeeds for '
        'axis-constrained irregular room', () {
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
    });

    test('dumped room can horizontalize line 2 with endpoint-pinned solve', () {
      final lines = dumpLines();
      final constraints = [
        ...dumpConstraints(),
        PlasterRoomConstraint.forInsert(
          roomId: 1,
          lineId: 2,
          type: PlasterConstraintType.horizontal,
        ),
      ];

      final targetLineIndex = lines.indexWhere((line) => line.id == 2);
      expect(targetLineIndex, isNonNegative);
      final nextIndex = (targetLineIndex + 1) % lines.length;
      final targetLine = lines[targetLineIndex];
      final targetEnd = PlasterGeometry.lineEnd(lines, targetLineIndex);

      final startPinnedLines = List<PlasterRoomLine>.from(lines);
      startPinnedLines[nextIndex] = startPinnedLines[nextIndex].copyWith(
        startY: targetLine.startY,
      );

      final endPinnedLines = List<PlasterRoomLine>.from(lines);
      endPinnedLines[targetLineIndex] = endPinnedLines[targetLineIndex]
          .copyWith(startY: targetEnd.y);

      final startPinnedSolve = PlasterConstraintSolver.solve(
        lines: startPinnedLines,
        constraints: constraints,
        pinnedVertexIndex: targetLineIndex,
        pinnedVertexTarget: IntPoint(targetLine.startX, targetLine.startY),
      );
      final endPinnedSolve = PlasterConstraintSolver.solve(
        lines: endPinnedLines,
        constraints: constraints,
        pinnedVertexIndex: nextIndex,
        pinnedVertexTarget: targetEnd,
      );

      expect(
        startPinnedSolve.converged || endPinnedSolve.converged,
        isTrue,
        reason: 'line 2 should be able to become horizontal in the dumped room',
      );
    });

    test('latest dumped room can horizontalize selected line within '
        'rounding tolerance', () {
      final lines = latestDumpLines();
      final constraints = [
        ...latestDumpConstraints(),
        PlasterRoomConstraint.forInsert(
          roomId: 1,
          lineId: 3,
          type: PlasterConstraintType.horizontal,
        ),
      ];

      final targetLineIndex = lines.indexWhere((line) => line.id == 3);
      expect(targetLineIndex, isNonNegative);
      final nextIndex = (targetLineIndex + 1) % lines.length;
      final targetLine = lines[targetLineIndex];
      final targetEnd = PlasterGeometry.lineEnd(lines, targetLineIndex);

      final startPinnedLines = List<PlasterRoomLine>.from(lines);
      startPinnedLines[nextIndex] = startPinnedLines[nextIndex].copyWith(
        startY: targetLine.startY,
      );

      final endPinnedLines = List<PlasterRoomLine>.from(lines);
      endPinnedLines[targetLineIndex] = endPinnedLines[targetLineIndex]
          .copyWith(startY: targetEnd.y);

      final startPinnedSolve = PlasterConstraintSolver.solve(
        lines: startPinnedLines,
        constraints: constraints,
        pinnedVertexIndex: targetLineIndex,
        pinnedVertexTarget: IntPoint(targetLine.startX, targetLine.startY),
      );
      final endPinnedSolve = PlasterConstraintSolver.solve(
        lines: endPinnedLines,
        constraints: constraints,
        pinnedVertexIndex: nextIndex,
        pinnedVertexTarget: targetEnd,
      );
      final freeSolve = PlasterConstraintSolver.solve(
        lines: lines,
        constraints: constraints,
      );

      expect(startPinnedSolve.converged, isTrue);
      expect(endPinnedSolve.converged, isTrue);
      expect(freeSolve.converged, isTrue);
    });
  });
}
