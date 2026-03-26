/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:math';

import '../../entity/plaster_room_constraint.dart';
import '../../entity/plaster_room_line.dart';
import 'plaster_geometry.dart';

class PlasterSolveResult {
  final List<PlasterRoomLine> lines;
  final bool converged;
  final double maxError;
  final List<PlasterConstraintViolation> violations;

  const PlasterSolveResult({
    required this.lines,
    required this.converged,
    required this.maxError,
    required this.violations,
  });
}

class PlasterConstraintViolation {
  final PlasterRoomConstraint constraint;
  final int lineIndex;
  final double error;

  const PlasterConstraintViolation({
    required this.constraint,
    required this.lineIndex,
    required this.error,
  });
}

class PlasterConstraintSolver {
  static const _maxIterations = 80;
  static const _positionTolerance = 0.75;
  static const _angleToleranceRadians = pi / 1800;
  static const _angleToleranceDegrees = 1.5;

  static const jointAngleUnitsPerDegree = 1000;

  static int degreesToAngleValue(double degrees) =>
      (degrees * jointAngleUnitsPerDegree).round();

  static double angleValueToDegrees(int value) =>
      value / jointAngleUnitsPerDegree;

  static int currentAngleValue(List<PlasterRoomLine> lines, int lineIndex) =>
      degreesToAngleValue(_currentAngleDegrees(lines, lineIndex));

  static PlasterSolveResult solve({
    required List<PlasterRoomLine> lines,
    required List<PlasterRoomConstraint> constraints,
    int? pinnedVertexIndex,
    IntPoint? pinnedVertexTarget,
  }) {
    if (lines.isEmpty) {
      return const PlasterSolveResult(
        lines: [],
        converged: true,
        maxError: 0,
        violations: [],
      );
    }

    final points = [
      for (final line in lines) _MutablePoint.xy(line.startX, line.startY),
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
          case PlasterConstraintType.lineLength:
            maxError = max(
              maxError,
              _enforceLength(
                points[lineIndex],
                points[nextIndex],
                constraint.targetValue?.toDouble() ?? 0,
              ),
            );
          case PlasterConstraintType.horizontal:
            maxError = max(
              maxError,
              _enforceHorizontal(points[lineIndex], points[nextIndex]),
            );
          case PlasterConstraintType.vertical:
            maxError = max(
              maxError,
              _enforceVertical(points[lineIndex], points[nextIndex]),
            );
          case PlasterConstraintType.jointAngle:
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
      if (maxError <= _positionTolerance) {
        break;
      }
    }

    final solved = PlasterGeometry.normalizeSeq([
      for (var i = 0; i < lines.length; i++)
        lines[i].copyWith(
          startX: points[i].x.round(),
          startY: points[i].y.round(),
        ),
    ]);

    final violations = _constraintViolations(solved, constraints);
    final converged = violations.isEmpty;
    return PlasterSolveResult(
      lines: solved,
      converged: converged,
      maxError: violations.isEmpty ? 0 : violations.first.error,
      violations: violations,
    );
  }

  static void _applyPinned(
    List<_MutablePoint> points,
    int? pinnedVertexIndex,
    IntPoint? pinnedVertexTarget,
  ) {
    if (pinnedVertexIndex == null || pinnedVertexTarget == null) {
      return;
    }
    points[pinnedVertexIndex]
      ..x = pinnedVertexTarget.x.toDouble()
      ..y = pinnedVertexTarget.y.toDouble();
  }

  static double _enforceLength(
    _MutablePoint a,
    _MutablePoint b,
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

  static double _enforceHorizontal(_MutablePoint a, _MutablePoint b) {
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

  static double _enforceVertical(_MutablePoint a, _MutablePoint b) {
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
    _MutablePoint prev,
    _MutablePoint pivot,
    _MutablePoint next,
    double targetAngleRadians,
  ) {
    final prevVector = _MutablePoint(prev.x - pivot.x, prev.y - pivot.y);
    final nextVector = _MutablePoint(next.x - pivot.x, next.y - pivot.y);
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

  static _MutablePoint _rotate(_MutablePoint point, double radians) {
    final cosAngle = cos(radians);
    final sinAngle = sin(radians);
    return _MutablePoint(
      point.x * cosAngle - point.y * sinAngle,
      point.x * sinAngle + point.y * cosAngle,
    );
  }

  static double _currentAngleDegrees(
    List<PlasterRoomLine> lines,
    int lineIndex,
  ) {
    final prevIndex = (lineIndex - 1 + lines.length) % lines.length;
    final prevPoint = lines[prevIndex];
    final pivot = lines[lineIndex];
    final nextPoint = lines[(lineIndex + 1) % lines.length];
    final a = _MutablePoint(
      prevPoint.startX.toDouble() - pivot.startX.toDouble(),
      prevPoint.startY.toDouble() - pivot.startY.toDouble(),
    );
    final b = _MutablePoint(
      nextPoint.startX.toDouble() - pivot.startX.toDouble(),
      nextPoint.startY.toDouble() - pivot.startY.toDouble(),
    );
    final dot = a.x * b.x + a.y * b.y;
    final cross = a.x * b.y - a.y * b.x;
    return atan2(cross.abs(), dot) * 180 / pi;
  }

  static List<PlasterConstraintViolation> _constraintViolations(
    List<PlasterRoomLine> lines,
    List<PlasterRoomConstraint> constraints,
  ) {
    final violations = <PlasterConstraintViolation>[];
    for (final constraint in constraints) {
      final lineIndex = lines.indexWhere(
        (line) => line.id == constraint.lineId,
      );
      if (lineIndex == -1) {
        continue;
      }
      final end = PlasterGeometry.lineEnd(lines, lineIndex);
      final line = lines[lineIndex];
      double? error;
      switch (constraint.type) {
        case PlasterConstraintType.lineLength:
          error =
              (line.length - (constraint.targetValue ?? line.length))
                  .abs()
                  .toDouble();
        case PlasterConstraintType.horizontal:
          error = (line.startY - end.y).abs().toDouble();
        case PlasterConstraintType.vertical:
          error = (line.startX - end.x).abs().toDouble();
        case PlasterConstraintType.jointAngle:
          final actualAngle = currentAngleValue(lines, lineIndex);
          error =
              (actualAngle - (constraint.targetValue ?? actualAngle)).abs() /
              jointAngleUnitsPerDegree;
      }
      if (!_isConstraintSatisfied(constraint.type, error)) {
        violations.add(
          PlasterConstraintViolation(
            constraint: constraint,
            lineIndex: lineIndex,
            error: error,
          ),
        );
      }
    }
    violations.sort((a, b) => b.error.compareTo(a.error));
    return violations;
  }

  static bool _isConstraintSatisfied(
    PlasterConstraintType type,
    double error,
  ) => switch (type) {
    PlasterConstraintType.lineLength => error <= _positionTolerance,
    PlasterConstraintType.horizontal => error <= _positionTolerance,
    PlasterConstraintType.vertical => error <= _positionTolerance,
    PlasterConstraintType.jointAngle => error <= _angleToleranceDegrees,
  };
}

class _MutablePoint {
  double x;
  double y;
  bool pinned;

  _MutablePoint(this.x, this.y) : pinned = false;

  _MutablePoint.xy(int x, int y)
    : x = x.toDouble(),
      y = y.toDouble(),
      pinned = false;

  double get length => sqrt(x * x + y * y);

  _MutablePoint operator *(double factor) =>
      _MutablePoint(x * factor, y * factor);
}
