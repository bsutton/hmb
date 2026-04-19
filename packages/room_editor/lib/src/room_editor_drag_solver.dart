import 'dart:math';

import 'package:flutter/foundation.dart';

import '../room_editor.dart';

enum RoomEditorDragSolvePhase { preview, commit }

class RoomEditorDragSolveRequest {
  static var _nextTraceId = 0;

  final RoomEditorDocument currentDocument;
  final RoomEditorDocument? gestureBaseDocument;
  final int movedIndex;
  final RoomEditorIntPoint movedTarget;
  final double emitDistanceThreshold;
  final RoomEditorDragSolvePhase phase;
  final int traceId;
  final int createdAtMicros;

  RoomEditorDragSolveRequest({
    required this.currentDocument,
    required this.movedIndex,
    required this.movedTarget,
    required this.emitDistanceThreshold,
    this.phase = RoomEditorDragSolvePhase.preview,
    this.gestureBaseDocument,
    int? traceId,
    int? createdAtMicros,
  }) : traceId = traceId ?? _nextTraceId++,
       createdAtMicros =
           createdAtMicros ?? DateTime.now().microsecondsSinceEpoch;

  @override
  String toString() =>
      'DragSolveRequest(#$traceId'
      ', phase=${phase.name}'
      ', movedIndex: $movedIndex, movedTarget: $movedTarget)';
}

class RoomEditorDragSolveResult {
  final RoomEditorDragSolveRequest request;
  final RoomEditorDocument? solvedDocument;
  final bool rigidConstraintClamp;

  const RoomEditorDragSolveResult({
    required this.request,
    required this.solvedDocument,
    this.rigidConstraintClamp = false,
  });
}

class RoomEditorDragSolver {
  static final _resultCache = <String, RoomEditorDragSolveResult>{};
  static const _maxCacheEntries = 64;
  static const _commitSeedReuseTolerance = 1.5;

  static RoomEditorDragSolveResult solve(RoomEditorDragSolveRequest request) {
    final totalStopwatch = Stopwatch()..start();
    final cacheKey = _requestKey(request);
    final cached = _resultCache[cacheKey];
    if (cached != null) {
      debugPrint(
        '[room_drag] solve cache hit'
        ' #${request.traceId}'
        ' phase=${request.phase.name}'
        ' totalLag=${_latencyMs(request)}ms',
      );
      return cached;
    }
    final primarySolveTarget = _projectTargetToIncomingConstraints(
      request.gestureBaseDocument ?? request.currentDocument,
      request.movedIndex,
      request.movedTarget,
    );
    final solveTargets = <RoomEditorIntPoint>[primarySolveTarget];
    if (primarySolveTarget.x != request.movedTarget.x ||
        primarySolveTarget.y != request.movedTarget.y) {
      solveTargets.add(request.movedTarget);
    }
    if (_isRigidOrthogonalConstraintSystem(request.currentDocument)) {
      final currentLine =
          request.currentDocument.bundle.lines[request.movedIndex];
      if (currentLine.startX != request.movedTarget.x ||
          currentLine.startY != request.movedTarget.y) {
        final clampedResult = RoomEditorDragSolveResult(
          request: request,
          solvedDocument: request.currentDocument,
          rigidConstraintClamp: true,
        );
        debugPrint(
          '[room_drag] rigid clamp'
          ' #${request.traceId}'
          ' phase=${request.phase.name}'
          ' totalLag=${_latencyMs(request)}ms',
        );
        _resultCache[cacheKey] = clampedResult;
        if (_resultCache.length > _maxCacheEntries) {
          _resultCache.remove(_resultCache.keys.first);
        }
        return clampedResult;
      }
    }
    final includeGestureBaseSeed = !_shouldSkipGestureBaseSeed(
      request,
      primarySolveTarget,
    );
    final seeds = <RoomEditorDocument>[];
    final seenSeedKeys = <String>{};
    for (final seed in [
      request.currentDocument,
      if (includeGestureBaseSeed && request.gestureBaseDocument != null)
        request.gestureBaseDocument!,
    ]) {
      final seedKey = _documentKey(seed);
      if (seenSeedKeys.add(seedKey)) {
        seeds.add(seed);
      }
    }
    final anchorPins = _dragAnchorPins(
      request.gestureBaseDocument ?? request.currentDocument,
      request.movedIndex,
    );

    RoomEditorDocument? bestDocument;
    double? bestScore;

    for (final seed in seeds) {
      for (final solveTarget in solveTargets) {
        final seedStopwatch = Stopwatch()..start();
        final seedLabel = identical(seed, request.currentDocument)
            ? 'current'
            : 'gestureBase';
        var lines = List<RoomEditorLine>.from(seed.bundle.lines);
        lines[request.movedIndex] = lines[request.movedIndex].copyWith(
          startX: solveTarget.x,
          startY: solveTarget.y,
        );
        lines = _preconditionIncomingFixedAxisDrag(
          seed,
          request.movedIndex,
          solveTarget,
          lines,
        );
        final candidate = normalizeRoomEditorOpenings(
          seed.copyWith(bundle: seed.bundle.copyWith(lines: lines)),
        );
        final result = RoomEditorConstraintSolver.solve(
          lines: candidate.bundle.lines,
          constraints: effectiveRoomEditorConstraints(candidate),
          pinnedVertexIndex: request.movedIndex,
          pinnedVertexTarget: solveTarget,
          additionalPinnedVertices: anchorPins,
        );
        seedStopwatch.stop();
        debugPrint(
          '[room_drag] seed solve'
          ' #${request.traceId}'
          ' phase=${request.phase.name}'
          ' seed=$seedLabel'
          ' target=(${solveTarget.x},${solveTarget.y})'
          ' duration=${seedStopwatch.elapsedMilliseconds}ms'
          ' converged=${result.converged}',
        );
        if (!result.converged) {
          continue;
        }
        final solvedDocument = candidate.copyWith(
          bundle: candidate.bundle.copyWith(lines: result.lines),
        );
        final score = _dragSolutionDistance(
          solvedDocument.bundle.lines,
          request.currentDocument.bundle.lines,
          movedIndex: request.movedIndex,
          movedTarget: request.movedTarget,
        );
        if (bestScore == null || score < bestScore) {
          bestScore = score;
          bestDocument = solvedDocument;
        }
      }
    }

    final finalResult = RoomEditorDragSolveResult(
      request: request,
      solvedDocument: bestDocument,
    );
    totalStopwatch.stop();
    debugPrint(
      '[room_drag] solve complete'
      ' #${request.traceId}'
      ' phase=${request.phase.name}'
      ' seeds=${seeds.length} targets=${solveTargets.length}'
      ' solved=${bestDocument != null}'
      ' solveDuration=${totalStopwatch.elapsedMilliseconds}ms'
      ' totalLag=${_latencyMs(request)}ms',
    );
    _resultCache[cacheKey] = finalResult;
    if (_resultCache.length > _maxCacheEntries) {
      _resultCache.remove(_resultCache.keys.first);
    }
    return finalResult;
  }

  static List<RoomEditorLine> _preconditionIncomingFixedAxisDrag(
    RoomEditorDocument document,
    int movedIndex,
    RoomEditorIntPoint solveTarget,
    List<RoomEditorLine> candidateLines,
  ) {
    final reference = document.bundle.lines;
    if (reference.isEmpty) {
      return candidateLines;
    }
    final previousIndex =
        (movedIndex - 1 + reference.length) % reference.length;
    final beforePreviousIndex =
        (previousIndex - 1 + reference.length) % reference.length;
    final previousLine = reference[previousIndex];
    final beforePreviousLine = reference[beforePreviousIndex];
    final currentPoint = reference[movedIndex];
    final previousConstraints = [
      for (final constraint in document.constraints)
        if (constraint.lineId == previousLine.id) constraint,
    ];
    final lengthConstraint = previousConstraints
        .where(
          (constraint) =>
              constraint.type == RoomEditorConstraintType.lineLength,
        )
        .cast<RoomEditorConstraint?>()
        .firstWhere((constraint) => constraint != null, orElse: () => null);
    final targetLength = lengthConstraint?.targetValue;
    if (targetLength == null || targetLength <= 0) {
      return candidateLines;
    }
    final beforePreviousConstraints = [
      for (final constraint in document.constraints)
        if (constraint.lineId == beforePreviousLine.id) constraint,
    ];
    final beforePreviousIsHorizontal = beforePreviousConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.horizontal,
    );
    final beforePreviousIsVertical = beforePreviousConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.vertical,
    );
    final hasVertical = previousConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.vertical,
    );
    if (hasVertical && beforePreviousIsHorizontal) {
      final direction = _axisDirection(
        current: previousLine.startY,
        anchor: currentPoint.startY,
        fallback: previousLine.startY - currentPoint.startY,
      );
      final previousStartY = solveTarget.y + (direction * targetLength);
      final lines = List<RoomEditorLine>.from(candidateLines);
      lines[previousIndex] = lines[previousIndex].copyWith(
        startX: solveTarget.x,
        startY: previousStartY,
      );
      if (beforePreviousIsHorizontal) {
        lines[beforePreviousIndex] = lines[beforePreviousIndex].copyWith(
          startY: previousStartY,
        );
      }
      return lines;
    }
    final hasHorizontal = previousConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.horizontal,
    );
    if (hasHorizontal && beforePreviousIsVertical) {
      final direction = _axisDirection(
        current: previousLine.startX,
        anchor: currentPoint.startX,
        fallback: previousLine.startX - currentPoint.startX,
      );
      final previousStartX = solveTarget.x + (direction * targetLength);
      final lines = List<RoomEditorLine>.from(candidateLines);
      lines[previousIndex] = lines[previousIndex].copyWith(
        startX: previousStartX,
        startY: solveTarget.y,
      );
      if (beforePreviousIsVertical) {
        lines[beforePreviousIndex] = lines[beforePreviousIndex].copyWith(
          startX: previousStartX,
        );
      }
      return lines;
    }
    return candidateLines;
  }

  static double _dragSolutionDistance(
    List<RoomEditorLine> candidate,
    List<RoomEditorLine> reference, {
    required int movedIndex,
    required RoomEditorIntPoint movedTarget,
  }) {
    var score = 0.0;
    for (var i = 0; i < candidate.length; i++) {
      final desiredX = i == movedIndex ? movedTarget.x : reference[i].startX;
      final desiredY = i == movedIndex ? movedTarget.y : reference[i].startY;
      final dx = candidate[i].startX - desiredX;
      final dy = candidate[i].startY - desiredY;
      final weight = i == movedIndex ? 4.0 : 1.0;
      score += (dx * dx + dy * dy) * weight;
    }
    return score;
  }

  static List<({int index, RoomEditorIntPoint target})> _dragAnchorPins(
    RoomEditorDocument referenceDocument,
    int movedIndex,
  ) {
    final reference = referenceDocument.bundle.lines;
    if (reference.length < 2) {
      return const [];
    }
    final excluded = {
      movedIndex,
      (movedIndex - 1 + reference.length) % reference.length,
      (movedIndex + 1) % reference.length,
    };
    var bestIndex = -1;
    var bestDistance = -1.0;
    final movedPoint = reference[movedIndex];
    for (var i = 0; i < reference.length; i++) {
      if (excluded.contains(i)) {
        continue;
      }
      final dx = reference[i].startX - movedPoint.startX;
      final dy = reference[i].startY - movedPoint.startY;
      final distance = (dx * dx + dy * dy).toDouble();
      if (distance > bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex == -1) {
      return const [];
    }
    final anchor = reference[bestIndex];
    return [
      (
        index: bestIndex,
        target: RoomEditorIntPoint(anchor.startX, anchor.startY),
      ),
    ];
  }

  static RoomEditorIntPoint _projectTargetToIncomingConstraints(
    RoomEditorDocument document,
    int movedIndex,
    RoomEditorIntPoint movedTarget,
  ) {
    final lines = document.bundle.lines;
    if (lines.isEmpty) {
      return movedTarget;
    }
    final previousIndex = (movedIndex - 1 + lines.length) % lines.length;
    final beforePreviousIndex =
        (previousIndex - 1 + lines.length) % lines.length;
    final nextIndex = (movedIndex + 1) % lines.length;
    final previousLine = lines[previousIndex];
    final beforePreviousLine = lines[beforePreviousIndex];
    final currentLine = lines[movedIndex];
    final nextLine = lines[nextIndex];
    final anchor = RoomEditorIntPoint(previousLine.startX, previousLine.startY);
    final currentPoint = lines[movedIndex];
    final previousConstraints = [
      for (final constraint in document.constraints)
        if (constraint.lineId == previousLine.id) constraint,
    ];
    final currentConstraints = [
      for (final constraint in document.constraints)
        if (constraint.lineId == currentLine.id) constraint,
    ];

    final hasHorizontal = previousConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.horizontal,
    );
    final hasVertical = previousConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.vertical,
    );
    final lengthConstraint = previousConstraints
        .where(
          (constraint) =>
              constraint.type == RoomEditorConstraintType.lineLength,
        )
        .cast<RoomEditorConstraint?>()
        .firstWhere((constraint) => constraint != null, orElse: () => null);
    final beforePreviousIsHorizontal = document.constraints.any(
      (constraint) =>
          constraint.lineId == beforePreviousLine.id &&
          constraint.type == RoomEditorConstraintType.horizontal,
    );
    final beforePreviousIsVertical = document.constraints.any(
      (constraint) =>
          constraint.lineId == beforePreviousLine.id &&
          constraint.type == RoomEditorConstraintType.vertical,
    );
    final beforePreviousLengthConstraint = document.constraints
        .where(
          (constraint) =>
              constraint.lineId == beforePreviousLine.id &&
              constraint.type == RoomEditorConstraintType.lineLength,
        )
        .cast<RoomEditorConstraint?>()
        .firstWhere((constraint) => constraint != null, orElse: () => null);
    final beforePreviousHasFixedLength =
        (beforePreviousLengthConstraint?.targetValue ?? 0) > 0;
    final currentHasHorizontal = currentConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.horizontal,
    );
    final currentHasVertical = currentConstraints.any(
      (constraint) => constraint.type == RoomEditorConstraintType.vertical,
    );
    final nextHasHorizontal = document.constraints.any(
      (constraint) =>
          constraint.lineId == nextLine.id &&
          constraint.type == RoomEditorConstraintType.horizontal,
    );
    final nextHasVertical = document.constraints.any(
      (constraint) =>
          constraint.lineId == nextLine.id &&
          constraint.type == RoomEditorConstraintType.vertical,
    );
    final nextLengthConstraint = document.constraints
        .where(
          (constraint) =>
              constraint.lineId == nextLine.id &&
              constraint.type == RoomEditorConstraintType.lineLength,
        )
        .cast<RoomEditorConstraint?>()
        .firstWhere((constraint) => constraint != null, orElse: () => null);
    final nextHasFixedLength = (nextLengthConstraint?.targetValue ?? 0) > 0;

    final targetLength = lengthConstraint?.targetValue;
    if (targetLength == null || targetLength <= 0) {
      if (hasVertical &&
          beforePreviousIsHorizontal &&
          beforePreviousHasFixedLength) {
        return RoomEditorIntPoint(currentPoint.startX, movedTarget.y);
      }
      if (hasHorizontal &&
          beforePreviousIsVertical &&
          beforePreviousHasFixedLength) {
        return RoomEditorIntPoint(movedTarget.x, currentPoint.startY);
      }
      if (currentHasHorizontal && nextHasVertical && nextHasFixedLength) {
        return RoomEditorIntPoint(movedTarget.x, currentPoint.startY);
      }
      if (currentHasVertical && nextHasHorizontal && nextHasFixedLength) {
        return RoomEditorIntPoint(currentPoint.startX, movedTarget.y);
      }
      return movedTarget;
    }

    if (targetLength > 0 && (hasHorizontal || hasVertical)) {
      const axisIntentTolerance = 24;
      if (hasVertical && beforePreviousIsHorizontal) {
        final horizontalDelta = (movedTarget.x - currentPoint.startX).abs();
        if (horizontalDelta <= axisIntentTolerance) {
          return movedTarget;
        }
        return RoomEditorIntPoint(movedTarget.x, currentPoint.startY);
      }
      if (hasHorizontal && beforePreviousIsVertical) {
        final verticalDelta = (movedTarget.y - currentPoint.startY).abs();
        if (verticalDelta <= axisIntentTolerance) {
          return movedTarget;
        }
        return RoomEditorIntPoint(currentPoint.startX, movedTarget.y);
      }
      return movedTarget;
    }

    if (hasVertical) {
      final direction = _axisDirection(
        current: movedTarget.y,
        anchor: anchor.y,
        fallback: movedTarget.y - anchor.y,
      );
      return RoomEditorIntPoint(
        anchor.x,
        anchor.y + (direction * targetLength),
      );
    }
    if (hasHorizontal) {
      final direction = _axisDirection(
        current: movedTarget.x,
        anchor: anchor.x,
        fallback: movedTarget.x - anchor.x,
      );
      return RoomEditorIntPoint(
        anchor.x + (direction * targetLength),
        anchor.y,
      );
    }

    final dx = movedTarget.x - anchor.x;
    final dy = movedTarget.y - anchor.y;
    final distance = sqrt((dx * dx) + (dy * dy));
    if (distance == 0) {
      final referencePoint = lines[movedIndex];
      final fallbackX = referencePoint.startX - anchor.x;
      final fallbackY = referencePoint.startY - anchor.y;
      final fallbackDistance = sqrt(
        (fallbackX * fallbackX) + (fallbackY * fallbackY),
      );
      if (fallbackDistance == 0) {
        return RoomEditorIntPoint(anchor.x + targetLength, anchor.y);
      }
      final scale = targetLength / fallbackDistance;
      return RoomEditorIntPoint(
        anchor.x + (fallbackX * scale).round(),
        anchor.y + (fallbackY * scale).round(),
      );
    }
    final scale = targetLength / distance;
    return RoomEditorIntPoint(
      anchor.x + (dx * scale).round(),
      anchor.y + (dy * scale).round(),
    );
  }

  static int _axisDirection({
    required int current,
    required int anchor,
    required int fallback,
  }) {
    final delta = current - anchor;
    if (delta > 0) {
      return 1;
    }
    if (delta < 0) {
      return -1;
    }
    if (fallback > 0) {
      return 1;
    }
    if (fallback < 0) {
      return -1;
    }
    return 1;
  }

  static bool _isRigidOrthogonalConstraintSystem(RoomEditorDocument document) {
    final lines = document.bundle.lines;
    if (lines.length < 3) {
      return false;
    }
    final lineLengthIds = <int>{};
    final angleIds = <int>{};
    final axisIds = <int>{};
    for (final constraint in document.constraints) {
      switch (constraint.type) {
        case RoomEditorConstraintType.lineLength:
          lineLengthIds.add(constraint.lineId);
        case RoomEditorConstraintType.jointAngle:
          angleIds.add(constraint.lineId);
        case RoomEditorConstraintType.horizontal:
        case RoomEditorConstraintType.vertical:
          axisIds.add(constraint.lineId);
        case RoomEditorConstraintType.parallel:
          break;
      }
    }
    return lines.every((line) => lineLengthIds.contains(line.id)) &&
        lines.every((line) => angleIds.contains(line.id)) &&
        lines.every((line) => axisIds.contains(line.id));
  }

  static String _requestKey(RoomEditorDragSolveRequest request) => [
    request.phase.name,
    request.movedIndex,
    request.movedTarget.x,
    request.movedTarget.y,
    _documentKey(request.currentDocument),
    if (request.gestureBaseDocument == null)
      '<none>'
    else
      _documentKey(request.gestureBaseDocument!),
  ].join('|');

  static String _documentKey(RoomEditorDocument document) => [
    for (final line in document.bundle.lines)
      '''
${line.id}:${line.startX}:${line.startY}:${line.length}''',
    '#',
    for (final constraint in document.constraints)
      '''
${constraint.lineId}:${constraint.type.name}:${constraint.targetValue ?? '-'}''',
  ].join(';');

  static int _latencyMs(RoomEditorDragSolveRequest request) =>
      ((DateTime.now().microsecondsSinceEpoch - request.createdAtMicros) / 1000)
          .round();

  static bool _shouldSkipGestureBaseSeed(
    RoomEditorDragSolveRequest request,
    RoomEditorIntPoint solveTarget,
  ) {
    if (request.phase != RoomEditorDragSolvePhase.commit ||
        request.gestureBaseDocument == null) {
      return false;
    }
    final currentPoint =
        request.currentDocument.bundle.lines[request.movedIndex];
    final dx = currentPoint.startX - solveTarget.x;
    final dy = currentPoint.startY - solveTarget.y;
    final distance = sqrt((dx * dx) + (dy * dy));
    if (distance > _commitSeedReuseTolerance) {
      return false;
    }
    return RoomEditorConstraintViolation.constraintViolations(
      request.currentDocument.bundle.lines,
      request.currentDocument.constraints,
    ).isEmpty;
  }
}
