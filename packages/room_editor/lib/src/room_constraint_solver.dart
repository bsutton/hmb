import 'dart:math';

import 'package:flutter/foundation.dart';

import '../room_editor.dart';
import 'mutable_point.dart';

class RoomEditorConstraintSolver {
  static const _maxIterations = 80;
  static const _solverPositionTolerance = 0.75;
  static const _angleToleranceRadians = pi / 1800;
  static const _stagnationIterations = 6;
  static const _stagnationErrorEpsilon = 0.01;
  static const _stagnationMovementEpsilon = 0.01;
  static var debugLoggingEnabled = true;

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
    List<({int index, RoomEditorIntPoint target})> additionalPinnedVertices =
        const [],
  }) {
    _logSolveStart(
      lines: lines,
      constraints: constraints,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
      additionalPinnedVertices: additionalPinnedVertices,
    );
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
    for (final pin in additionalPinnedVertices) {
      points[pin.index]
        ..x = pin.target.x.toDouble()
        ..y = pin.target.y.toDouble()
        ..pinned = true;
    }

    var maxError = 0.0;
    var iterations = 0;
    var stagnationCount = 0;
    double? previousMaxError;
    var previousPositions = [for (final point in points) (point.x, point.y)];
    for (var iteration = 0; iteration < _maxIterations; iteration++) {
      iterations = iteration + 1;
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
      _applyPinned(
        points,
        pinnedIndex,
        pinnedVertexTarget,
        additionalPinnedVertices,
      );
      final movement = _positionDelta(points, previousPositions);
      if (previousMaxError != null &&
          (previousMaxError - maxError).abs() <= _stagnationErrorEpsilon &&
          movement <= _stagnationMovementEpsilon) {
        stagnationCount++;
      } else {
        stagnationCount = 0;
      }
      previousMaxError = maxError;
      previousPositions = [for (final point in points) (point.x, point.y)];
      if (maxError <= _solverPositionTolerance) {
        break;
      }
      if (stagnationCount >= _stagnationIterations) {
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
    _logSolveEnd(
      result: result,
      iterations: iterations,
      lines: lines,
      solved: solved,
      pinnedVertexIndex: pinnedVertexIndex,
      pinnedVertexTarget: pinnedVertexTarget,
      additionalPinnedVertices: additionalPinnedVertices,
      loopMaxError: maxError,
      stagnated: stagnationCount >= _stagnationIterations,
    );
    return result;
  }

  static void _logSolveStart({
    required List<RoomEditorLine> lines,
    required List<RoomEditorConstraint> constraints,
    required int? pinnedVertexIndex,
    required RoomEditorIntPoint? pinnedVertexTarget,
    required List<({int index, RoomEditorIntPoint target})>
    additionalPinnedVertices,
  }) {
    if (!debugLoggingEnabled ||
        (pinnedVertexIndex == null && additionalPinnedVertices.isEmpty)) {
      return;
    }
    debugPrint(
      '[room_solver] start'
      ' pinnedIndex=$pinnedVertexIndex'
      ' pinnedTarget=${_formatPoint(pinnedVertexTarget)}'
      ' extraPins=${_formatPins(additionalPinnedVertices)}'
      ' lines=${_formatLines(lines)}'
      ' constraints=${_formatConstraints(constraints)}',
    );
  }

  static void _logSolveEnd({
    required RoomEditorSolveResult result,
    required int iterations,
    required List<RoomEditorLine> lines,
    required List<RoomEditorLine> solved,
    required int? pinnedVertexIndex,
    required RoomEditorIntPoint? pinnedVertexTarget,
    required List<({int index, RoomEditorIntPoint target})>
    additionalPinnedVertices,
    required double loopMaxError,
    required bool stagnated,
  }) {
    if (!debugLoggingEnabled ||
        (pinnedVertexIndex == null && additionalPinnedVertices.isEmpty)) {
      return;
    }
    debugPrint(
      '[room_solver] end'
      ' pinnedIndex=$pinnedVertexIndex'
      ' pinnedTarget=${_formatPoint(pinnedVertexTarget)}'
      ' extraPins=${_formatPins(additionalPinnedVertices)}'
      ' converged=${result.converged}'
      ' iterations=$iterations'
      ' stagnated=$stagnated'
      ' loopMaxError=${loopMaxError.toStringAsFixed(3)}'
      ' violationMaxError=${result.maxError.toStringAsFixed(3)}'
      ' before=${_formatLines(lines)}'
      ' after=${_formatLines(solved)}'
      ' violations=${_formatViolations(result.violations)}',
    );
  }

  static double _positionDelta(
    List<MutablePoint> points,
    List<(double, double)> previousPositions,
  ) {
    var maxDelta = 0.0;
    for (var i = 0; i < points.length; i++) {
      final dx = points[i].x - previousPositions[i].$1;
      final dy = points[i].y - previousPositions[i].$2;
      maxDelta = max(maxDelta, sqrt(dx * dx + dy * dy));
    }
    return maxDelta;
  }

  static String _formatPoint(RoomEditorIntPoint? point) =>
      point == null ? '<none>' : '(${point.x},${point.y})';

  static String _formatPins(
    List<({int index, RoomEditorIntPoint target})> pins,
  ) => pins.isEmpty
      ? '<none>'
      : [
          for (final pin in pins) '${pin.index}:${_formatPoint(pin.target)}',
        ].join(', ');

  static String _formatLines(List<RoomEditorLine> lines) => [
    for (var i = 0; i < lines.length; i++)
      {
        '$i:${lines[i].id}@(${lines[i].startX},${lines[i].startY})',
        '->${_formatPoint(RoomCanvasGeometry.lineEnd(lines, i))}',
      },
  ].join(' | ');

  static String _formatConstraints(List<RoomEditorConstraint> constraints) => [
    for (final constraint in constraints)
      {
        '${constraint.lineId}:${constraint.type.name}',
        '=${constraint.targetValue ?? '-'}',
      },
  ].join(', ');

  static String _formatViolations(
    List<RoomEditorConstraintViolation> violations,
  ) {
    if (violations.isEmpty) {
      return '<none>';
    }
    return [
      for (final violation in violations)
        {
          '${violation.constraint.lineId}:${violation.constraint.type.name}',
          '@${violation.error.toStringAsFixed(3)}',
        },
    ].join(', ');
  }

  static void _applyPinned(
    List<MutablePoint> points,
    int? pinnedVertexIndex,
    RoomEditorIntPoint? pinnedVertexTarget,
    List<({int index, RoomEditorIntPoint target})> additionalPinnedVertices,
  ) {
    if (pinnedVertexIndex != null && pinnedVertexTarget != null) {
      points[pinnedVertexIndex]
        ..x = pinnedVertexTarget.x.toDouble()
        ..y = pinnedVertexTarget.y.toDouble();
    }
    for (final pin in additionalPinnedVertices) {
      points[pin.index]
        ..x = pin.target.x.toDouble()
        ..y = pin.target.y.toDouble();
    }
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
