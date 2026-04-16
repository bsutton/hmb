import 'dart:math';

import '../../entity/plaster_room_constraint.dart';
import '../../entity/plaster_room_line.dart';
import 'plaster_constraint_solver.dart';
import 'plaster_geometry.dart';

class PlasterConstraintViolation {
  static const _snappedGeometryTolerance = 1.0;
  static const _angleToleranceDegrees = 1.5;

  final PlasterRoomConstraint constraint;
  final int lineIndex;
  final double error;

  const PlasterConstraintViolation({
    required this.constraint,
    required this.lineIndex,
    required this.error,
  });

  static bool isConstraintSatisfied(PlasterConstraintType type, double error) =>
      switch (type) {
        PlasterConstraintType.lineLength => error <= _snappedGeometryTolerance,
        PlasterConstraintType.horizontal => error <= _snappedGeometryTolerance,
        PlasterConstraintType.vertical => error <= _snappedGeometryTolerance,
        PlasterConstraintType.jointAngle => error <= _angleToleranceDegrees,
        PlasterConstraintType.parallel => error <= _angleToleranceDegrees,
      };

  static List<PlasterConstraintViolation> constraintViolations(
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
          error = (line.length - (constraint.targetValue ?? line.length))
              .abs()
              .toDouble();
        case PlasterConstraintType.horizontal:
          error = (line.startY - end.y).abs().toDouble();
        case PlasterConstraintType.vertical:
          error = (line.startX - end.x).abs().toDouble();
        case PlasterConstraintType.jointAngle:
          final actualAngle = PlasterConstraintSolver.currentAngleValue(
            lines,
            lineIndex,
          );
          error =
              (actualAngle - (constraint.targetValue ?? actualAngle)).abs() /
              PlasterConstraintSolver.jointAngleUnitsPerDegree;
        case PlasterConstraintType.parallel:
          final targetLineIndex = lines.indexWhere(
            (line) => line.id == constraint.targetValue,
          );
          if (targetLineIndex == -1) {
            continue;
          }
          final targetEnd = PlasterGeometry.lineEnd(lines, targetLineIndex);
          final targetLine = lines[targetLineIndex];
          final lineAngle = _lineAngle(line, end);
          final targetAngle = _lineAngle(targetLine, targetEnd);
          error = _parallelAngleErrorDegrees(lineAngle, targetAngle);
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
    PlasterConstraintType.lineLength => error <= _snappedGeometryTolerance,
    PlasterConstraintType.horizontal => error <= _snappedGeometryTolerance,
    PlasterConstraintType.vertical => error <= _snappedGeometryTolerance,
    PlasterConstraintType.jointAngle => error <= _angleToleranceDegrees,
    PlasterConstraintType.parallel => error <= _angleToleranceDegrees,
  };

  static double _lineAngle(PlasterRoomLine line, IntPoint end) =>
      atan2((end.y - line.startY).toDouble(), (end.x - line.startX).toDouble());

  static double _parallelAngleErrorDegrees(double left, double right) {
    final difference = (left - right).abs();
    final normalized = min(difference, (pi - difference).abs());
    return normalized * 180 / pi;
  }
}
