import 'dart:math';

import '../room_editor.dart';

enum RoomEditorDocumentConstraintState {
  underConstrained,
  fullyConstrained,
  invalid,
}

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

List<RoomEditorConstraintViolation> deriveBlockingConstraintViolations({
  required RoomEditorDocument document,
  int? pinnedVertexIndex,
  RoomEditorIntPoint? pinnedVertexTarget,
  List<({int index, RoomEditorIntPoint target})> additionalPinnedVertices =
      const [],
  RoomEditorSolveResult? failedSolveResult,
  int limit = 3,
}) {
  final baseline =
      failedSolveResult ??
      RoomEditorConstraintSolver.solve(
        lines: document.bundle.lines,
        constraints: effectiveRoomEditorConstraints(document),
        pinnedVertexIndex: pinnedVertexIndex,
        pinnedVertexTarget: pinnedVertexTarget,
        additionalPinnedVertices: additionalPinnedVertices,
      );
  if (baseline.converged || effectiveRoomEditorConstraints(document).isEmpty) {
    return const [];
  }

  final previousLogging = RoomEditorConstraintSolver.debugLoggingEnabled;
  RoomEditorConstraintSolver.debugLoggingEnabled = false;
  try {
    final baselinePenalty = _solvePenalty(baseline);
    final attemptedLines = document.bundle.lines;
    final candidates = <_BlockingConstraintCandidate>[];
    for (final constraint in effectiveRoomEditorConstraints(document)) {
      final reducedConstraints = [
        for (final candidate in effectiveRoomEditorConstraints(document))
          if (!_sameConstraint(candidate, constraint)) candidate,
      ];
      final rerun = RoomEditorConstraintSolver.solve(
        lines: attemptedLines,
        constraints: reducedConstraints,
        pinnedVertexIndex: pinnedVertexIndex,
        pinnedVertexTarget: pinnedVertexTarget,
        additionalPinnedVertices: additionalPinnedVertices,
      );
      final improvement = baselinePenalty - _solvePenalty(rerun);
      final materiallyImproves =
          rerun.converged ||
          improvement > max(1.0, max(baseline.maxError, 1) * 0.1);
      if (!materiallyImproves) {
        continue;
      }
      final lineIndex = document.bundle.lines.indexWhere(
        (line) => line.id == constraint.lineId,
      );
      candidates.add(
        _BlockingConstraintCandidate(
          violation: RoomEditorConstraintViolation(
            constraint: constraint,
            lineIndex: lineIndex < 0 ? 0 : lineIndex,
            error: improvement,
          ),
          converged: rerun.converged,
          improvement: improvement,
          geometryDeviation: _geometryDeviationPenalty(
            rerun.lines,
            attemptedLines,
          ),
        ),
      );
    }
    candidates.sort(_compareBlockingConstraintCandidates);
    if (candidates.isNotEmpty) {
      return candidates
          .take(limit)
          .map((candidate) => candidate.violation)
          .toList(growable: false);
    }
  } finally {
    RoomEditorConstraintSolver.debugLoggingEnabled = previousLogging;
  }

  return baseline.violations.take(limit).toList(growable: false);
}

int _compareBlockingConstraintCandidates(
  _BlockingConstraintCandidate left,
  _BlockingConstraintCandidate right,
) {
  if (left.converged != right.converged) {
    return left.converged ? -1 : 1;
  }
  final geometryComparison = left.geometryDeviation.compareTo(
    right.geometryDeviation,
  );
  if (geometryComparison != 0) {
    return geometryComparison;
  }
  return right.improvement.compareTo(left.improvement);
}

double _solvePenalty(RoomEditorSolveResult result) {
  var penalty = result.maxError + (result.violations.length * 1000);
  if (!result.converged) {
    penalty += 100000;
  }
  return penalty;
}

double _geometryDeviationPenalty(
  List<RoomEditorLine> actual,
  List<RoomEditorLine> attempted,
) {
  final count = min(actual.length, attempted.length);
  var penalty = 0.0;
  for (var index = 0; index < count; index++) {
    penalty += (actual[index].startX - attempted[index].startX).abs();
    penalty += (actual[index].startY - attempted[index].startY).abs();
  }
  return penalty;
}

class _BlockingConstraintCandidate {
  final RoomEditorConstraintViolation violation;
  final bool converged;
  final double improvement;
  final double geometryDeviation;

  const _BlockingConstraintCandidate({
    required this.violation,
    required this.converged,
    required this.improvement,
    required this.geometryDeviation,
  });
}

bool _sameConstraint(RoomEditorConstraint left, RoomEditorConstraint right) =>
    left.lineId == right.lineId &&
    left.type == right.type &&
    left.targetValue == right.targetValue;

RoomEditorDocumentConstraintState deriveRoomEditorDocumentConstraintState(
  RoomEditorDocument document,
) {
  final lines = document.bundle.lines;
  if (lines.isEmpty) {
    return RoomEditorDocumentConstraintState.underConstrained;
  }

  final directViolations = RoomEditorConstraintViolation.constraintViolations(
    lines,
    effectiveRoomEditorConstraints(document),
  );
  if (directViolations.isNotEmpty) {
    return RoomEditorDocumentConstraintState.invalid;
  }

  if (_documentHasMobility(document)) {
    return RoomEditorDocumentConstraintState.underConstrained;
  }

  return RoomEditorDocumentConstraintState.fullyConstrained;
}

bool _documentHasMobility(RoomEditorDocument document) {
  final lines = document.bundle.lines;
  if (lines.length < 2 || effectiveRoomEditorConstraints(document).isEmpty) {
    return true;
  }

  final probes = <({int vertexIndex, RoomEditorIntPoint target})>[];
  final vertexCount = lines.length;
  final candidateIndices = <int>{0, 1 % vertexCount, vertexCount ~/ 2};

  for (final index in candidateIndices) {
    final line = lines[index];
    probes
      ..add((
        vertexIndex: index,
        target: RoomEditorIntPoint(line.startX + 24, line.startY),
      ))
      ..add((
        vertexIndex: index,
        target: RoomEditorIntPoint(line.startX, line.startY + 24),
      ));
  }

  final previousLogging = RoomEditorConstraintSolver.debugLoggingEnabled;
  RoomEditorConstraintSolver.debugLoggingEnabled = false;
  try {
    for (final probe in probes) {
      var anchorIndex = (probe.vertexIndex + (vertexCount ~/ 2)) % vertexCount;
      if (anchorIndex == probe.vertexIndex) {
        anchorIndex = (probe.vertexIndex + 1) % vertexCount;
      }
      final anchorLine = lines[anchorIndex];
      final result = RoomEditorConstraintSolver.solve(
        lines: lines,
        constraints: effectiveRoomEditorConstraints(document),
        pinnedVertexIndex: probe.vertexIndex,
        pinnedVertexTarget: probe.target,
        additionalPinnedVertices: [
          (
            index: anchorIndex,
            target: RoomEditorIntPoint(anchorLine.startX, anchorLine.startY),
          ),
        ],
      );
      if (result.converged) {
        return true;
      }
    }
  } finally {
    RoomEditorConstraintSolver.debugLoggingEnabled = previousLogging;
  }
  return false;
}

Set<int> deriveImplicitLengthConflictLineIndices({
  required RoomEditorDocument sourceDocument,
  required RoomEditorDocument attemptedDocument,
  required int movedVertexIndex,
  double tolerance = 1.0,
}) {
  final sourceLines = sourceDocument.bundle.lines;
  final attemptedLines = attemptedDocument.bundle.lines;
  if (sourceLines.length != attemptedLines.length || sourceLines.isEmpty) {
    return {};
  }
  if (movedVertexIndex < 0 || movedVertexIndex >= sourceLines.length) {
    return {};
  }

  final previousIndex =
      (movedVertexIndex - 1 + sourceLines.length) % sourceLines.length;
  final affected = <int>{previousIndex, movedVertexIndex};

  return {
    for (final lineIndex in affected)
      if ((_actualLineLength(sourceLines, lineIndex) -
                  _actualLineLength(attemptedLines, lineIndex))
              .abs() >
          tolerance)
        lineIndex,
  };
}

double _actualLineLength(List<RoomEditorLine> lines, int lineIndex) {
  final line = lines[lineIndex];
  final end = RoomCanvasGeometry.lineEnd(lines, lineIndex);
  final dx = (end.x - line.startX).toDouble();
  final dy = (end.y - line.startY).toDouble();
  return sqrt(dx * dx + dy * dy);
}
