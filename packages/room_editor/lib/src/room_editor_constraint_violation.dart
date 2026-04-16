import 'dart:math';

import '../room_editor.dart';

class RoomEditorConstraintViolation {
  static const _snappedGeometryTolerance = 1.0;
  static const _angleToleranceDegrees = 1.5;

  final RoomEditorConstraint constraint;
  final int lineIndex;
  final double error;

  const RoomEditorConstraintViolation({
    required this.constraint,
    required this.lineIndex,
    required this.error,
  });

  static List<RoomEditorConstraintViolation> constraintViolations(
    List<RoomEditorLine> lines,
    List<RoomEditorConstraint> constraints,
  ) {
    final violations = <RoomEditorConstraintViolation>[];
    for (final constraint in constraints) {
      final lineIndex = lines.indexWhere(
        (line) => line.id == constraint.lineId,
      );
      if (lineIndex == -1) {
        continue;
      }
      final end = RoomCanvasGeometry.lineEnd(lines, lineIndex);
      final line = lines[lineIndex];
      double? error;
      switch (constraint.type) {
        case RoomEditorConstraintType.lineLength:
          error = (line.length - (constraint.targetValue ?? line.length))
              .abs()
              .toDouble();
        case RoomEditorConstraintType.horizontal:
          error = (line.startY - end.y).abs().toDouble();
        case RoomEditorConstraintType.vertical:
          error = (line.startX - end.x).abs().toDouble();
        case RoomEditorConstraintType.jointAngle:
          final actualAngle = RoomEditorConstraintSolver.currentAngleValue(
            lines,
            lineIndex,
          );
          error =
              (actualAngle - (constraint.targetValue ?? actualAngle)).abs() /
              RoomEditorConstraintSolver.jointAngleUnitsPerDegree;
        case RoomEditorConstraintType.parallel:
          final targetLineIndex = lines.indexWhere(
            (line) => line.id == constraint.targetValue,
          );
          if (targetLineIndex == -1) {
            continue;
          }
          final targetEnd = RoomCanvasGeometry.lineEnd(lines, targetLineIndex);
          final targetLine = lines[targetLineIndex];
          final lineAngle = _lineAngle(line, end);
          final targetAngle = _lineAngle(targetLine, targetEnd);
          error = _parallelAngleErrorDegrees(lineAngle, targetAngle);
      }
      if (!_isConstraintSatisfied(constraint.type, error)) {
        violations.add(
          RoomEditorConstraintViolation(
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
    RoomEditorConstraintType type,
    double error,
  ) => switch (type) {
    RoomEditorConstraintType.lineLength => error <= _snappedGeometryTolerance,
    RoomEditorConstraintType.horizontal => error <= _snappedGeometryTolerance,
    RoomEditorConstraintType.vertical => error <= _snappedGeometryTolerance,
    RoomEditorConstraintType.jointAngle => error <= _angleToleranceDegrees,
    RoomEditorConstraintType.parallel => error <= _angleToleranceDegrees,
  };

  static double _lineAngle(RoomEditorLine line, RoomEditorIntPoint end) =>
      atan2((end.y - line.startY).toDouble(), (end.x - line.startX).toDouble());

  static double _parallelAngleErrorDegrees(double left, double right) {
    final difference = (left - right).abs();
    final normalized = min(difference, (pi - difference).abs());
    return normalized * 180 / pi;
  }
}
