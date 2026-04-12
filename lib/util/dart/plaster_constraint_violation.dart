import '../../entity/plaster_room_constraint.dart';

class PlasterConstraintViolation {
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
      };

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
          error = (line.length - (constraint.targetValue ?? line.length))
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
    PlasterConstraintType.lineLength => error <= _snappedGeometryTolerance,
    PlasterConstraintType.horizontal => error <= _snappedGeometryTolerance,
    PlasterConstraintType.vertical => error <= _snappedGeometryTolerance,
    PlasterConstraintType.jointAngle => error <= _angleToleranceDegrees,
  };
}
