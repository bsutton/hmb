import '../room_editor.dart';

class RoomEditorDragSolveRequest {
  final RoomEditorDocument currentDocument;
  final RoomEditorDocument? gestureBaseDocument;
  final int movedIndex;
  final RoomEditorIntPoint movedTarget;
  final double emitDistanceThreshold;

  const RoomEditorDragSolveRequest({
    required this.currentDocument,
    required this.movedIndex,
    required this.movedTarget,
    required this.emitDistanceThreshold,
    this.gestureBaseDocument,
  });
}

class RoomEditorDragSolveResult {
  final RoomEditorDragSolveRequest request;
  final RoomEditorDocument? solvedDocument;

  const RoomEditorDragSolveResult({
    required this.request,
    required this.solvedDocument,
  });
}

class RoomEditorDragSolver {
  static RoomEditorDragSolveResult solve(RoomEditorDragSolveRequest request) {
    final seeds = <RoomEditorDocument>[
      request.currentDocument,
      if (request.gestureBaseDocument != null) request.gestureBaseDocument!,
    ];
    final anchorPins = _dragAnchorPins(
      request.gestureBaseDocument ?? request.currentDocument,
      request.movedIndex,
    );

    RoomEditorDocument? bestDocument;
    double? bestScore;

    for (final seed in seeds) {
      final lines = List<RoomEditorLine>.from(seed.bundle.lines);
      lines[request.movedIndex] = lines[request.movedIndex].copyWith(
        startX: request.movedTarget.x,
        startY: request.movedTarget.y,
      );
      final candidate = seed.copyWith(
        bundle: seed.bundle.copyWith(lines: lines),
      );
      final result = RoomEditorConstraintSolver.solve(
        lines: candidate.bundle.lines,
        constraints: candidate.constraints,
        pinnedVertexIndex: request.movedIndex,
        pinnedVertexTarget: request.movedTarget,
        additionalPinnedVertices: anchorPins,
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

    return RoomEditorDragSolveResult(
      request: request,
      solvedDocument: bestDocument,
    );
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
}
