import 'dart:math';

import '../room_editor.dart';

import 'mutable_point.dart';
import 'room_canvas_geometry.dart';
import 'room_canvas_models.dart';
import 'room_editor_solve_result.dart';

class RoomEditorConstraintSolver {
  static const _maxIterations = 80;
  static const _solverPositionTolerance = 0.75;
  static const _angleToleranceRadians = pi / 1800;

  static const jointAngleUnitsPerDegree = 1000;

  static int degreesToAngleValue(double degrees) =>
      (degrees * jointAngleUnitsPerDegree).round();

  static double angleValueToDegrees(int value) =>
      value / jointAngleUnitsPerDegree;

  static int currentAngleValue(List<RoomEditorLine> lines, int lineIndex) =>
      degreesToAngleValue(_currentAngleDegrees(lines, lineIndex));

  static RoomEditorSolveResult solve({
    required List<RoomEditorLine> lines,
    required List<RoomEditorConstraint> constraints,
    int? pinnedVertexIndex,
    RoomEditorIntPoint? pinnedVertexTarget,
  }) {
    if (lines.isEmpty) {
      return const RoomEditorSolveResult(
        lines: [],
        converged: true,
        maxError: 0,
        violations: [],
      );
    }

    final points = [
      for (final line in lines) MutablePoint.xy(line.startX, line.startY),
    ];
    final pinnedIndex = pinnedVertexIndex;
    if (pinnedIndex != null && pinnedVertexTarget != null) {
      points[pinnedIndex]
        ..x = pinnedVertexTarget.x.toDouble()
        ..y = pinnedVertexTarget.y.toDouble()
        ..pinned = true;
    }

    var maxError = 0.0;
    for (var iteration = 0; iteration < _maxIterations; iteration++) {
      maxError = 0;
      for (final constraint in constraints) {
        final lineIndex = lines.indexWhere(
          (line) => line.id == constraint.lineId,
        );
        if (lineIndex == -1) {
          continue;
        }
        final nextIndex = (lineIndex + 1) % points.length;
        switch (constraint.type) {
          case RoomEditorConstraintType.lineLength:
            maxError = max(
              maxError,
              _enforceLength(
                points[lineIndex],
                points[nextIndex],
                constraint.targetValue?.toDouble() ?? 0,
              ),
            );
          case RoomEditorConstraintType.horizontal:
            maxError = max(
              maxError,
              _enforceHorizontal(points[lineIndex], points[nextIndex]),
            );
          case RoomEditorConstraintType.vertical:
            maxError = max(
              maxError,
              _enforceVertical(points[lineIndex], points[nextIndex]),
            );
          case RoomEditorConstraintType.jointAngle:
            final prevIndex = (lineIndex - 1 + points.length) % points.length;
            maxError = max(
              maxError,
              _enforceAngle(
                points[prevIndex],
                points[lineIndex],
                points[nextIndex],
                angleValueToDegrees(constraint.targetValue ?? 90000) * pi / 180,
              ),
            );
        }
      }
      _applyPinned(points, pinnedIndex, pinnedVertexTarget);
      if (maxError <= _solverPositionTolerance) {
        break;
      }
    }

    final solved = RoomCanvasGeometry.normalizeSeq([
      for (var i = 0; i < lines.length; i++)
        lines[i].copyWith(
          startX: points[i].x.round(),
          startY: points[i].y.round(),
        ),
    ]);

    final violations = RoomEditorConstraintViolation.constraintViolations(
      solved,
      constraints,
    );
    final converged = violations.isEmpty;
    final result = RoomEditorSolveResult(
      lines: solved,
      converged: converged,
      maxError: violations.isEmpty ? 0 : violations.first.error,
      violations: violations,
    );
    print(result);
    return result;
  }

  static void _applyPinned(
    List<MutablePoint> points,
    int? pinnedVertexIndex,
    RoomEditorIntPoint? pinnedVertexTarget,
  ) {
    if (pinnedVertexIndex == null || pinnedVertexTarget == null) {
      return;
    }
    points[pinnedVertexIndex]
      ..x = pinnedVertexTarget.x.toDouble()
      ..y = pinnedVertexTarget.y.toDouble();
  }

  static double _enforceLength(
    MutablePoint a,
    MutablePoint b,
    double targetLength,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final current = sqrt(dx * dx + dy * dy);
    if (current == 0 || targetLength <= 0) {
      return 0;
    }
    final error = current - targetLength;
    final correction = error / current / 2;
    final offsetX = dx * correction;
    final offsetY = dy * correction;

    if (!a.pinned && !b.pinned) {
      a
        ..x += offsetX
        ..y += offsetY;
      b
        ..x -= offsetX
        ..y -= offsetY;
    } else if (a.pinned && !b.pinned) {
      b
        ..x -= offsetX * 2
        ..y -= offsetY * 2;
    } else if (!a.pinned && b.pinned) {
      a
        ..x += offsetX * 2
        ..y += offsetY * 2;
    }
    return error.abs();
  }

  static double _enforceHorizontal(MutablePoint a, MutablePoint b) {
    final error = a.y - b.y;
    final targetY = (a.y + b.y) / 2;
    if (!a.pinned && !b.pinned) {
      a.y = targetY;
      b.y = targetY;
    } else if (a.pinned && !b.pinned) {
      b.y = a.y;
    } else if (!a.pinned && b.pinned) {
      a.y = b.y;
    }
    return error.abs();
  }

  static double _enforceVertical(MutablePoint a, MutablePoint b) {
    final error = a.x - b.x;
    final targetX = (a.x + b.x) / 2;
    if (!a.pinned && !b.pinned) {
      a.x = targetX;
      b.x = targetX;
    } else if (a.pinned && !b.pinned) {
      b.x = a.x;
    } else if (!a.pinned && b.pinned) {
      a.x = b.x;
    }
    return error.abs();
  }

  static double _enforceAngle(
    MutablePoint prev,
    MutablePoint pivot,
    MutablePoint next,
    double targetAngleRadians,
  ) {
    final prevVector = MutablePoint(prev.x - pivot.x, prev.y - pivot.y);
    final nextVector = MutablePoint(next.x - pivot.x, next.y - pivot.y);
    final prevLength = prevVector.length;
    final nextLength = nextVector.length;
    if (prevLength == 0 || nextLength == 0) {
      return 0;
    }

    final currentSigned = atan2(
      prevVector.x * nextVector.y - prevVector.y * nextVector.x,
      prevVector.x * nextVector.x + prevVector.y * nextVector.y,
    );
    final desiredSigned = currentSigned.isNegative
        ? -targetAngleRadians
        : targetAngleRadians;
    final error = currentSigned - desiredSigned;
    if (error.abs() <= _angleToleranceRadians) {
      return 0;
    }

    if (prev.pinned && next.pinned) {
      return error.abs() * 100;
    }
    if (prev.pinned && !next.pinned) {
      final rotated =
          _rotate(prevVector, desiredSigned) * (nextLength / prevLength);
      next
        ..x = pivot.x + rotated.x
        ..y = pivot.y + rotated.y;
      return error.abs() * 100;
    }
    if (!prev.pinned && next.pinned) {
      final rotated =
          _rotate(nextVector, -desiredSigned) * (prevLength / nextLength);
      prev
        ..x = pivot.x + rotated.x
        ..y = pivot.y + rotated.y;
      return error.abs() * 100;
    }

    final prevRotated = _rotate(prevVector, error / 2);
    final nextRotated = _rotate(nextVector, -error / 2);
    prev
      ..x = pivot.x + prevRotated.x
      ..y = pivot.y + prevRotated.y;
    next
      ..x = pivot.x + nextRotated.x
      ..y = pivot.y + nextRotated.y;
    return error.abs() * 100;
  }

  static MutablePoint _rotate(MutablePoint point, double radians) {
    final cosAngle = cos(radians);
    final sinAngle = sin(radians);
    return MutablePoint(
      point.x * cosAngle - point.y * sinAngle,
      point.x * sinAngle + point.y * cosAngle,
    );
  }

  static double _currentAngleDegrees(
    List<RoomEditorLine> lines,
    int lineIndex,
  ) {
    final prevIndex = (lineIndex - 1 + lines.length) % lines.length;
    final prevPoint = lines[prevIndex];
    final pivot = lines[lineIndex];
    final nextPoint = lines[(lineIndex + 1) % lines.length];
    final a = MutablePoint(
      prevPoint.startX.toDouble() - pivot.startX.toDouble(),
      prevPoint.startY.toDouble() - pivot.startY.toDouble(),
    );
    final b = MutablePoint(
      nextPoint.startX.toDouble() - pivot.startX.toDouble(),
      nextPoint.startY.toDouble() - pivot.startY.toDouble(),
    );
    final dot = a.x * b.x + a.y * b.y;
    final cross = a.x * b.y - a.y * b.x;
    return atan2(cross.abs(), dot) * 180 / pi;
  }
}
