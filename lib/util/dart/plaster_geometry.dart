/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../entity/plaster_material_size.dart';
import '../../entity/plaster_project.dart';
import '../../entity/plaster_room.dart';
import '../../entity/plaster_room_line.dart';
import '../../entity/plaster_room_opening.dart';
import 'log.dart';
import 'measurement_type.dart';
import 'plaster_layout_scoring.dart';
import 'plaster_sheet_direction.dart';

class IntPoint {
  final int x;
  final int y;

  const IntPoint(this.x, this.y);
}

class PlasterRoomShape {
  final PlasterProject? project;
  final PlasterRoom room;
  final List<PlasterRoomLine> lines;
  final List<PlasterRoomOpening> openings;

  const PlasterRoomShape({
    required this.room,
    required this.lines,
    required this.openings,
    this.project,
  });
}

class PlasterSheetPlacement {
  final int x;
  final int y;
  final int width;
  final int height;

  const PlasterSheetPlacement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class PlasterSheetUsagePiece {
  final int x;
  final int y;
  final int width;
  final int height;

  const PlasterSheetUsagePiece({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  int get area => width * height;
}

class PlasterSheetOffcut extends PlasterSheetUsagePiece {
  final bool reusable;
  final bool reusedLater;

  const PlasterSheetOffcut({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.reusable,
    this.reusedLater = false,
  });
}

class PlasterSheetUsage {
  final List<PlasterSheetUsagePiece> usedPieces;
  final List<PlasterSheetOffcut> offcuts;
  final int sheetWidth;
  final int sheetHeight;

  const PlasterSheetUsage({
    required this.usedPieces,
    required this.offcuts,
    required this.sheetWidth,
    required this.sheetHeight,
  });

  int get usedArea => usedPieces.fold<int>(0, (sum, piece) => sum + piece.area);
  int get reusableOffcutArea => offcuts.fold<int>(
    0,
    (sum, offcut) => sum + (offcut.reusable ? offcut.area : 0),
  );
  int get wasteArea => offcuts.fold<int>(
    0,
    (sum, offcut) => sum + (offcut.reusable ? 0 : offcut.area),
  );
}

class PlasterProjectSheetPiece extends PlasterSheetUsagePiece {
  final String surfaceLabel;
  final bool reusedOffcut;
  final int? sourceSheetIndex;
  final int? sourceSheetNumber;

  const PlasterProjectSheetPiece({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.surfaceLabel,
    required this.reusedOffcut,
    this.sourceSheetIndex,
    this.sourceSheetNumber,
  });
}

class PlasterProjectSheet {
  final int sheetNumber;
  final PlasterMaterialSize material;
  final int sheetWidth;
  final int sheetHeight;
  final List<PlasterProjectSheetPiece> usedPieces;
  final List<PlasterSheetOffcut> offcuts;

  const PlasterProjectSheet({
    required this.sheetNumber,
    required this.material,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.usedPieces,
    required this.offcuts,
  });
}

class PlasterSurfaceLayout {
  final int roomId;
  final int? lineId;
  final bool isCeiling;
  final String label;
  final PlasterMaterialSize material;
  final PlasterSheetDirection direction;
  final int width;
  final int height;
  final int area;
  final int sheetsAcross;
  final int sheetsDown;
  final int sheetCount;
  final int sheetCountWithWaste;
  final List<PlasterSheetPlacement> placements;
  final List<PlasterSheetUsage> sheetUsage;
  final int estimatedJointTapeLength;
  final int estimatedScrewCount;
  final double estimatedGlueKg;
  final double estimatedPlasterKg;

  const PlasterSurfaceLayout({
    required this.roomId,
    required this.lineId,
    required this.isCeiling,
    required this.label,
    required this.material,
    required this.direction,
    required this.width,
    required this.height,
    required this.area,
    required this.sheetsAcross,
    required this.sheetsDown,
    required this.sheetCount,
    required this.sheetCountWithWaste,
    required this.placements,
    required this.sheetUsage,
    required this.estimatedJointTapeLength,
    required this.estimatedScrewCount,
    required this.estimatedGlueKg,
    required this.estimatedPlasterKg,
  });
}

class PlasterTakeoffSummary {
  final int totalSheetCount;
  final int totalSheetCountWithWaste;
  final int surfaceArea;
  final int purchasedBoardArea;
  final int cutWasteArea;
  final int contingencyWasteArea;
  final int reusableOffcutArea;
  final int estimatedWasteArea;
  final double estimatedWastePercent;
  final int contingencySheetCount;
  final int corniceLength;
  final int insideCornerLength;
  final int outsideCornerLength;
  final int tapeLength;
  final int screwCount;
  final double glueKg;
  final double plasterKg;
  final double corniceCementKg;

  const PlasterTakeoffSummary({
    required this.totalSheetCount,
    required this.totalSheetCountWithWaste,
    required this.surfaceArea,
    required this.purchasedBoardArea,
    required this.cutWasteArea,
    required this.contingencyWasteArea,
    required this.reusableOffcutArea,
    required this.estimatedWasteArea,
    required this.estimatedWastePercent,
    required this.contingencySheetCount,
    required this.corniceLength,
    required this.insideCornerLength,
    required this.outsideCornerLength,
    required this.tapeLength,
    required this.screwCount,
    required this.glueKg,
    required this.plasterKg,
    required this.corniceCementKg,
  });

  const PlasterTakeoffSummary.zero()
    : totalSheetCount = 0,
      totalSheetCountWithWaste = 0,
      surfaceArea = 0,
      purchasedBoardArea = 0,
      cutWasteArea = 0,
      contingencyWasteArea = 0,
      reusableOffcutArea = 0,
      estimatedWasteArea = 0,
      estimatedWastePercent = 0,
      contingencySheetCount = 0,
      corniceLength = 0,
      insideCornerLength = 0,
      outsideCornerLength = 0,
      tapeLength = 0,
      screwCount = 0,
      glueKg = 0,
      plasterKg = 0,
      corniceCementKg = 0;
}

class PlasterAnalysisRequest {
  final List<PlasterRoomShape> roomShapes;
  final List<PlasterMaterialSize> materials;
  final int wastePercent;
  final PlasterLayoutScoring scoring;
  final int maxDurationMs;
  final int progressIntervalMs;

  const PlasterAnalysisRequest({
    required this.roomShapes,
    required this.materials,
    required this.wastePercent,
    this.scoring = const PlasterLayoutScoring.defaults(),
    this.maxDurationMs = 300000,
    this.progressIntervalMs = 300,
  });
}

class PlasterAnalysisResult {
  final List<PlasterSurfaceLayout> layouts;
  final PlasterTakeoffSummary takeoff;
  final int exploredStates;
  final int elapsedMs;
  final bool complete;
  final bool timedOut;
  final bool reachedTargetWaste;

  const PlasterAnalysisResult({
    required this.layouts,
    required this.takeoff,
    required this.exploredStates,
    required this.elapsedMs,
    required this.complete,
    required this.timedOut,
    required this.reachedTargetWaste,
  });
}

class PlasterAnalysisProgress {
  final int exploredStates;
  final int elapsedMs;
  final bool timedOut;
  final bool reachedTargetWaste;

  const PlasterAnalysisProgress({
    required this.exploredStates,
    required this.elapsedMs,
    required this.timedOut,
    required this.reachedTargetWaste,
  });
}

class PlasterAnalysisFailure {
  final String error;
  final String stackTrace;

  const PlasterAnalysisFailure({required this.error, required this.stackTrace});
}

class PlasterAnalysisIsolateRequest {
  final SendPort sendPort;
  final PlasterAnalysisRequest request;

  const PlasterAnalysisIsolateRequest({
    required this.sendPort,
    required this.request,
  });
}

class _FreeRect {
  final int x;
  final int y;
  final int width;
  final int height;
  final bool reusedLater;

  const _FreeRect(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.reusedLater = false,
  });

  bool isContainedIn(_FreeRect other) =>
      x >= other.x &&
      y >= other.y &&
      x + width <= other.x + other.width &&
      y + height <= other.y + other.height;

  int get area => width * height;
}

class _ProjectLayoutScore {
  final int sheetCount;
  final int wasteArea;
  final int fragmentationPenalty;
  final int reusableArea;
  final int jointTapeLength;
  final int buttJointLength;
  final int cutPieceCount;
  final int highJointLength;
  final int smallPieceCount;
  final int verticalWallCount;

  const _ProjectLayoutScore({
    required this.sheetCount,
    required this.wasteArea,
    required this.fragmentationPenalty,
    required this.reusableArea,
    required this.jointTapeLength,
    required this.buttJointLength,
    required this.cutPieceCount,
    required this.highJointLength,
    required this.smallPieceCount,
    required this.verticalWallCount,
  });
}

class _ProjectLayoutState {
  final List<PlasterSurfaceLayout> layouts;
  final _ProjectLayoutScore score;

  const _ProjectLayoutState({required this.layouts, required this.score});
}

class _PackedSheet {
  final List<_FreeRect> freeRects;
  final List<PlasterSheetUsagePiece> usedPieces;
  final int usedArea;

  const _PackedSheet({
    required this.freeRects,
    required this.usedPieces,
    required this.usedArea,
  });

  _PackedSheet copy() => _PackedSheet(
    freeRects: [
      for (final rect in freeRects)
        _FreeRect(
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          reusedLater: rect.reusedLater,
        ),
    ],
    usedPieces: [
      for (final piece in usedPieces)
        PlasterSheetUsagePiece(
          x: piece.x,
          y: piece.y,
          width: piece.width,
          height: piece.height,
        ),
    ],
    usedArea: usedArea,
  );
}

class _PackingState {
  final List<_PackedSheet> sheets;
  final int usedArea;
  final _ProjectLayoutScore score;

  const _PackingState({
    required this.sheets,
    required this.usedArea,
    required this.score,
  });
}

class _PackingResult {
  final int sheetCount;
  final int wasteArea;
  final int usedArea;
  final int fragmentationPenalty;
  final int reusableArea;
  final List<PlasterSheetUsage> sheetUsage;

  const _PackingResult({
    required this.sheetCount,
    required this.wasteArea,
    required this.usedArea,
    required this.fragmentationPenalty,
    required this.reusableArea,
    required this.sheetUsage,
  });
}

class _PlacementChoice {
  final int sheetIndex;
  final int rectIndex;
  final int pieceWidth;
  final int pieceHeight;
  final List<_FreeRect> freeRects;
  final int leftoverArea;
  final int fragmentationPenalty;
  final int reusableArea;

  const _PlacementChoice({
    required this.sheetIndex,
    required this.rectIndex,
    required this.pieceWidth,
    required this.pieceHeight,
    required this.freeRects,
    required this.leftoverArea,
    required this.fragmentationPenalty,
    required this.reusableArea,
  });
}

class _PackableSurfacePiece {
  final String surfaceLabel;
  final int width;
  final int height;

  const _PackableSurfacePiece({
    required this.surfaceLabel,
    required this.width,
    required this.height,
  });
}

class _ExplorerPackedSheet {
  final List<_FreeRect> freeRects;
  final List<PlasterProjectSheetPiece> usedPieces;

  const _ExplorerPackedSheet({
    required this.freeRects,
    required this.usedPieces,
  });

  _ExplorerPackedSheet copy() => _ExplorerPackedSheet(
    freeRects: [
      for (final rect in freeRects)
        _FreeRect(
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          reusedLater: rect.reusedLater,
        ),
    ],
    usedPieces: [
      for (final piece in usedPieces)
        PlasterProjectSheetPiece(
          x: piece.x,
          y: piece.y,
          width: piece.width,
          height: piece.height,
          surfaceLabel: piece.surfaceLabel,
          reusedOffcut: piece.reusedOffcut,
          sourceSheetIndex: piece.sourceSheetIndex,
          sourceSheetNumber: piece.sourceSheetNumber,
        ),
    ],
  );
}

class _PlasterSearchBudget {
  final stopwatch = Stopwatch()..start();
  final int maxDurationMs;
  final int progressIntervalMs;
  final int wastePercent;
  final PlasterLayoutScoring scoring;
  final List<PlasterRoomShape> roomShapes;
  final void Function(Object message)? onProgress;

  var exploredStates = 0;
  var _lastProgressMs = -1;
  var timedOut = false;
  var reachedTargetWaste = false;
  _ProjectLayoutScore? _bestScore;

  _PlasterSearchBudget({
    required this.maxDurationMs,
    required this.progressIntervalMs,
    required this.wastePercent,
    required this.scoring,
    required this.roomShapes,
    required this.onProgress,
  });

  int get elapsedMs => stopwatch.elapsedMilliseconds;

  bool get isExpired => elapsedMs >= maxDurationMs;

  bool tick() {
    if (reachedTargetWaste) {
      return true;
    }
    exploredStates++;
    if (isExpired) {
      timedOut = true;
      return true;
    }
    return false;
  }

  void maybeReportProgress({bool force = false}) {
    if (onProgress == null) {
      return;
    }
    final shouldReport =
        force ||
        _lastProgressMs < 0 ||
        elapsedMs - _lastProgressMs >= progressIntervalMs;
    if (!shouldReport) {
      return;
    }
    _lastProgressMs = elapsedMs;
    onProgress!(
      PlasterAnalysisProgress(
        exploredStates: exploredStates,
        elapsedMs: elapsedMs,
        timedOut: timedOut,
        reachedTargetWaste: reachedTargetWaste,
      ),
    );
  }

  void maybeReport(
    List<PlasterSurfaceLayout> layouts,
    _ProjectLayoutScore score, {
    bool force = false,
    bool complete = false,
    PlasterTakeoffSummary? takeoff,
  }) {
    if (onProgress == null || layouts.isEmpty) {
      return;
    }
    final shouldReplaceBest =
        _bestScore == null ||
        PlasterGeometry._isBetterProjectScore(score, _bestScore!, scoring);
    final shouldReport = force || shouldReplaceBest;
    if (!shouldReport) {
      return;
    }
    if (shouldReplaceBest) {
      _bestScore = score;
    }
    _lastProgressMs = elapsedMs;
    final resolvedTakeoff =
        takeoff ??
        PlasterGeometry.calculateTakeoff(roomShapes, layouts, wastePercent);
    if (resolvedTakeoff.estimatedWastePercent <= wastePercent + 1) {
      reachedTargetWaste = true;
    }
    onProgress!(
      PlasterAnalysisResult(
        layouts: layouts,
        takeoff: resolvedTakeoff,
        exploredStates: exploredStates,
        elapsedMs: elapsedMs,
        complete: complete,
        timedOut: timedOut,
        reachedTargetWaste: reachedTargetWaste,
      ),
    );
  }
}

void plasterAnalyzeProjectInIsolate(PlasterAnalysisIsolateRequest message) {
  try {
    final result = PlasterGeometry.analyzeProject(
      message.request,
      onProgress: (progress) => message.sendPort.send(progress),
    );
    message.sendPort.send(result);
  } catch (error, stackTrace) {
    message.sendPort.send(
      PlasterAnalysisFailure(
        error: error.toString(),
        stackTrace: stackTrace.toString(),
      ),
    );
  }
}

class PlasterGeometry {
  static const _debugSurfaceCandidateLogging = true;

  static const metricUnitsPerMm = 10;
  static const imperialUnitsPerInch = 1000;
  static const inchesPerFoot = 12;
  static const metricGrid = 1000;
  static const imperialGrid = 6000;
  static const metricMinEdgePiece = 3000;
  static const imperialMinEdgePiece = 11811;

  static int defaultRoomSize(PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric ? 30000 : 120000;

  static int defaultCeilingHeight(PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric ? 24000 : 96000;

  static List<PlasterRoomLine> defaultLines({
    required int roomId,
    required PreferredUnitSystem unitSystem,
  }) {
    final size = defaultRoomSize(unitSystem);
    return [
      PlasterRoomLine.forInsert(
        roomId: roomId,
        seqNo: 0,
        startX: 0,
        startY: 0,
        length: size,
      ),
      PlasterRoomLine.forInsert(
        roomId: roomId,
        seqNo: 1,
        startX: size,
        startY: 0,
        length: size,
      ),
      PlasterRoomLine.forInsert(
        roomId: roomId,
        seqNo: 2,
        startX: size,
        startY: size,
        length: size,
      ),
      PlasterRoomLine.forInsert(
        roomId: roomId,
        seqNo: 3,
        startX: 0,
        startY: size,
        length: size,
      ),
    ];
  }

  static IntPoint lineEnd(List<PlasterRoomLine> lines, int index) {
    final next = lines[(index + 1) % lines.length];
    return IntPoint(next.startX, next.startY);
  }

  static int derivedLength(List<PlasterRoomLine> lines, int index) {
    final line = lines[index];
    final end = lineEnd(lines, index);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    return sqrt(dx * dx + dy * dy).round();
  }

  static List<PlasterRoomLine> normalizeSeq(List<PlasterRoomLine> lines) => [
    for (var i = 0; i < lines.length; i++)
      lines[i].copyWith(seqNo: i, length: derivedLength(lines, i)),
  ];

  static int defaultGridSize(PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric ? metricGrid : imperialGrid;

  static List<PlasterRoomLine> moveIntersection(
    List<PlasterRoomLine> lines,
    int index,
    IntPoint point,
  ) {
    final updated = List<PlasterRoomLine>.from(lines);
    updated[index] = updated[index].copyWith(startX: point.x, startY: point.y);
    return normalizeSeq(updated);
  }

  static List<PlasterRoomLine> setLength(
    List<PlasterRoomLine> lines,
    int lineIndex,
    int newLength,
  ) {
    final line = lines[lineIndex];
    final end = lineEnd(lines, lineIndex);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    final currentLength = sqrt(dx * dx + dy * dy);
    if (currentLength == 0) {
      return lines;
    }
    final ratio = newLength / currentLength;
    final newEnd = IntPoint(
      line.startX + (dx * ratio).round(),
      line.startY + (dy * ratio).round(),
    );
    return moveIntersection(lines, (lineIndex + 1) % lines.length, newEnd);
  }

  static IntPoint snapPoint(IntPoint point, PreferredUnitSystem unitSystem) {
    final grid = defaultGridSize(unitSystem);
    return IntPoint(
      ((point.x / grid).round()) * grid,
      ((point.y / grid).round()) * grid,
    );
  }

  static List<PlasterRoomLine> splitLine(
    List<PlasterRoomLine> lines,
    int lineIndex,
  ) {
    final line = lines[lineIndex];
    final end = lineEnd(lines, lineIndex);
    if (line.startX == end.x && line.startY == end.y) {
      return lines;
    }
    final midpoint = IntPoint(
      ((line.startX + end.x) / 2).round(),
      ((line.startY + end.y) / 2).round(),
    );
    final updated = <PlasterRoomLine>[];
    for (var i = 0; i < lines.length; i++) {
      updated.add(lines[i]);
      if (i == lineIndex) {
        updated.add(
          PlasterRoomLine.forInsert(
            roomId: line.roomId,
            seqNo: 0,
            startX: midpoint.x,
            startY: midpoint.y,
            length: 0,
            plasterSelected: line.plasterSelected,
            sheetDirection: line.sheetDirection,
          ),
        );
      }
    }
    return normalizeSeq(updated);
  }

  static List<PlasterRoomLine> deleteIntersection(
    List<PlasterRoomLine> lines,
    int index,
  ) {
    if (lines.length <= 4) {
      return lines;
    }
    final updated = List<PlasterRoomLine>.from(lines)..removeAt(index);
    return normalizeSeq(updated);
  }

  static int polygonArea(List<PlasterRoomLine> lines) {
    var area = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final end = lineEnd(lines, i);
      area += line.startX * end.y - end.x * line.startY;
    }
    return area.abs() ~/ 2;
  }

  static int openingArea(PlasterRoomOpening opening) =>
      opening.width * opening.height;

  static List<PlasterRoomLine> ensureLineLength(
    List<PlasterRoomLine> lines,
    int lineIndex,
    int minimumLength,
  ) {
    if (lines[lineIndex].length >= minimumLength) {
      return lines;
    }
    return setLength(lines, lineIndex, minimumLength);
  }

  static int lineNetArea(
    PlasterRoom room,
    List<PlasterRoomLine> lines,
    List<PlasterRoomOpening> openings,
    int lineIndex,
  ) {
    final line = lines[lineIndex];
    final openingAreaSum = openings
        .where((opening) => opening.lineId == line.id)
        .fold<int>(0, (sum, opening) => sum + openingArea(opening));
    return max(0, line.length * room.ceilingHeight - openingAreaSum);
  }

  static double toDisplay(int value, PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric
      ? value / metricUnitsPerMm
      : value / imperialUnitsPerInch / inchesPerFoot;

  static int fromDisplay(double value, PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric
      ? (value * metricUnitsPerMm).round()
      : (value * inchesPerFoot * imperialUnitsPerInch).round();

  static String unitLabel(PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric ? 'mm' : 'ft/in';

  static String formatDisplayArea(int area, PreferredUnitSystem unitSystem) {
    if (unitSystem == PreferredUnitSystem.metric) {
      final squareMeters = area / 100000000;
      return '${squareMeters.toStringAsFixed(2)} m²';
    }
    final squareFeet =
        area / (imperialUnitsPerInch * imperialUnitsPerInch) / 144;
    return '${squareFeet.toStringAsFixed(2)} ft²';
  }

  static String formatDisplayLength(int value, PreferredUnitSystem unitSystem) {
    if (unitSystem == PreferredUnitSystem.metric) {
      return '${(value / metricUnitsPerMm).round()} mm';
    }

    final totalInches = value / imperialUnitsPerInch;
    final feet = totalInches ~/ inchesPerFoot;
    final remainingInches = totalInches - feet * inchesPerFoot;
    final wholeInches = remainingInches.floor();
    final fractionalInches = remainingInches - wholeInches;
    final sixteenths = (fractionalInches * 16).round();

    if (sixteenths == 16) {
      return _formatFeetAndInches(feet, wholeInches + 1, 0);
    }

    return _formatFeetAndInches(feet, wholeInches, sixteenths);
  }

  static String formatLinearTakeoffLength(
    int value,
    PreferredUnitSystem unitSystem,
  ) {
    if (unitSystem == PreferredUnitSystem.metric) {
      final meters = value / metricUnitsPerMm / 1000;
      return '${meters.toStringAsFixed(2)} m';
    }

    final feet = value / imperialUnitsPerInch / inchesPerFoot;
    return '${feet.toStringAsFixed(2)} ft';
  }

  static int? parseDisplayLength(String raw, PreferredUnitSystem unitSystem) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (unitSystem == PreferredUnitSystem.metric) {
      final mm = double.tryParse(value);
      if (mm == null) {
        return null;
      }
      return (mm * metricUnitsPerMm).round();
    }

    final normalized = value
        .toLowerCase()
        .replaceAll('feet', "'")
        .replaceAll('foot', "'")
        .replaceAll('ft', "'")
        .replaceAll('inches', '"')
        .replaceAll('inch', '"')
        .replaceAll('in', '"')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final quotePattern = RegExp(
      r'''^\s*(\d+)\s*'\s*(?:(\d+)(?:\s+(\d+)\/(\d+))?|(\d+)\/(\d+))?\s*"?\s*$''',
    );
    final quoteMatch = quotePattern.firstMatch(normalized);
    if (quoteMatch != null) {
      final feet = int.parse(quoteMatch.group(1)!);
      final inches = int.tryParse(quoteMatch.group(2) ?? '') ?? 0;
      final numerator =
          int.tryParse(quoteMatch.group(3) ?? quoteMatch.group(4) ?? '') ?? 0;
      final denominator =
          int.tryParse(quoteMatch.group(4) ?? quoteMatch.group(5) ?? '') ?? 1;
      return _fromFeetAndInches(feet, inches, numerator, denominator);
    }

    final parts = normalized.replaceAll('"', '').split(' ');
    if (parts.length == 2 &&
        int.tryParse(parts[0]) != null &&
        int.tryParse(parts[1]) != null) {
      return _fromFeetAndInches(int.parse(parts[0]), int.parse(parts[1]), 0, 1);
    }

    final decimalFeet = double.tryParse(normalized.replaceAll("'", ''));
    if (decimalFeet == null) {
      return null;
    }
    return fromDisplay(decimalFeet, PreferredUnitSystem.imperial);
  }

  static String _formatFeetAndInches(int feet, int inches, int sixteenths) {
    final normalizedFeet = feet + inches ~/ inchesPerFoot;
    final normalizedInches = inches % inchesPerFoot;
    if (sixteenths == 0) {
      return "$normalizedFeet' $normalizedInches\"";
    }
    final divisor = _gcd(sixteenths, 16);
    final numerator = sixteenths ~/ divisor;
    final denominator = 16 ~/ divisor;
    return "$normalizedFeet' $normalizedInches $numerator/$denominator\"";
  }

  static int _fromFeetAndInches(
    int feet,
    int inches,
    int numerator,
    int denominator,
  ) {
    final totalInches =
        feet * inchesPerFoot +
        inches +
        (denominator == 0 ? 0 : numerator / denominator);
    return (totalInches * imperialUnitsPerInch).round();
  }

  static int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final remainder = x % y;
      x = y;
      y = remainder;
    }
    return x == 0 ? 1 : x;
  }

  static int convertLength(
    int value,
    PreferredUnitSystem from,
    PreferredUnitSystem to,
  ) {
    if (from == to) {
      return value;
    }
    if (from == PreferredUnitSystem.metric) {
      final inches = value / metricUnitsPerMm / 25.4;
      return (inches * imperialUnitsPerInch).round();
    }
    final mm = value / imperialUnitsPerInch * 25.4;
    return (mm * metricUnitsPerMm).round();
  }

  static (PlasterRoom, List<PlasterRoomLine>, List<PlasterRoomOpening>)
  convertRoomBundle({
    required PlasterRoom room,
    required List<PlasterRoomLine> lines,
    required List<PlasterRoomOpening> openings,
    required PreferredUnitSystem target,
  }) {
    if (room.unitSystem == target) {
      return (room, lines, openings);
    }

    final convertedLines = normalizeSeq([
      for (final line in lines)
        line.copyWith(
          startX: convertLength(line.startX, room.unitSystem, target),
          startY: convertLength(line.startY, room.unitSystem, target),
          length: convertLength(line.length, room.unitSystem, target),
        ),
    ]);

    final convertedOpenings = [
      for (final opening in openings)
        opening.copyWith(
          offsetFromStart: convertLength(
            opening.offsetFromStart,
            room.unitSystem,
            target,
          ),
          width: convertLength(opening.width, room.unitSystem, target),
          height: convertLength(opening.height, room.unitSystem, target),
          sillHeight: convertLength(
            opening.sillHeight,
            room.unitSystem,
            target,
          ),
        ),
    ];

    return (
      room.copyWith(
        unitSystem: target,
        ceilingHeight: convertLength(
          room.ceilingHeight,
          room.unitSystem,
          target,
        ),
      ),
      convertedLines,
      convertedOpenings,
    );
  }

  static int minEdgePiece(PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric
      ? metricMinEdgePiece
      : imperialMinEdgePiece;

  static PlasterAnalysisResult analyzeProject(
    PlasterAnalysisRequest request, {
    void Function(Object message)? onProgress,
  }) {
    final budget = _PlasterSearchBudget(
      maxDurationMs: request.maxDurationMs,
      progressIntervalMs: request.progressIntervalMs,
      wastePercent: request.wastePercent,
      scoring: request.scoring,
      roomShapes: request.roomShapes,
      onProgress: onProgress,
    );
    final bestState = _calculateLayoutState(
      request.roomShapes,
      request.materials,
      budget: budget,
    );
    final takeoff = calculateTakeoff(
      request.roomShapes,
      bestState.layouts,
      request.wastePercent,
    );
    budget.maybeReport(
      bestState.layouts,
      bestState.score,
      force: true,
      complete: true,
      takeoff: takeoff,
    );
    return PlasterAnalysisResult(
      layouts: bestState.layouts,
      takeoff: takeoff,
      exploredStates: budget.exploredStates,
      elapsedMs: budget.elapsedMs,
      complete: true,
      timedOut: budget.timedOut,
      reachedTargetWaste: budget.reachedTargetWaste,
    );
  }

  static List<PlasterSurfaceLayout> calculateLayout(
    List<PlasterRoomShape> roomShapes,
    List<PlasterMaterialSize> materials,
  ) => _calculateLayoutState(roomShapes, materials).layouts;

  static _ProjectLayoutState _calculateLayoutState(
    List<PlasterRoomShape> roomShapes,
    List<PlasterMaterialSize> materials, {
    _PlasterSearchBudget? budget,
  }) {
    const planWaves = <int>[18, 36, 72, 144, 288];
    var best = const _ProjectLayoutState(
      layouts: [],
      score: _ProjectLayoutScore(
        sheetCount: 0,
        wasteArea: 0,
        fragmentationPenalty: 0,
        reusableArea: 0,
        jointTapeLength: 0,
        buttJointLength: 0,
        cutPieceCount: 0,
        highJointLength: 0,
        smallPieceCount: 0,
        verticalWallCount: 0,
      ),
    );

    for (final planLimit in planWaves) {
      if (budget?.isExpired ?? false) {
        break;
      }
      if (budget?.reachedTargetWaste ?? false) {
        break;
      }
      final candidateGroups = _candidateGroupsForPlanLimit(
        roomShapes,
        materials,
        planLimit: planLimit,
      );
      final candidate = _optimizeProjectLayouts(
        candidateGroups,
        roomShapes,
        budget: budget,
      );
      if (best.layouts.isEmpty ||
          _isBetterProjectScore(candidate.score, best.score, budget?.scoring)) {
        best = candidate;
      }
    }

    return best;
  }

  static List<List<PlasterSurfaceLayout>> _candidateGroupsForPlanLimit(
    List<PlasterRoomShape> roomShapes,
    List<PlasterMaterialSize> materials, {
    required int planLimit,
  }) {
    final candidateGroups = <List<PlasterSurfaceLayout>>[];
    for (final shape in roomShapes) {
      if (shape.lines.isEmpty) {
        continue;
      }
      for (var i = 0; i < shape.lines.length; i++) {
        final line = shape.lines[i];
        if (!line.plasterSelected) {
          continue;
        }
        final candidates = _surfaceCandidates(
          shape: shape,
          line: line,
          room: shape.room,
          lineId: line.id,
          isCeiling: false,
          direction: line.sheetDirection,
          width: line.length,
          height: shape.room.ceilingHeight,
          area: lineNetArea(shape.room, shape.lines, shape.openings, i),
          materials: materials,
          label: _surfaceLabel(
            name: '${shape.room.name} wall ${i + 1}',
            width: line.length,
            height: shape.room.ceilingHeight,
            unitSystem: shape.room.unitSystem,
          ),
        );
        if (candidates.isNotEmpty) {
          candidateGroups.add(candidates);
        }
      }
      if (shape.room.plasterCeiling) {
        final bounds = _bounds(shape.lines);
        final candidates = _surfaceCandidates(
          shape: shape,
          line: null,
          room: shape.room,
          lineId: null,
          isCeiling: true,
          direction: shape.room.ceilingSheetDirection,
          width: bounds.$3 - bounds.$1,
          height: bounds.$4 - bounds.$2,
          area: polygonArea(shape.lines),
          materials: materials,
          label: _surfaceLabel(
            name: '${shape.room.name} ceiling',
            width: bounds.$3 - bounds.$1,
            height: bounds.$4 - bounds.$2,
            unitSystem: shape.room.unitSystem,
          ),
        );
        if (candidates.isNotEmpty) {
          candidateGroups.add(candidates);
        }
      }
    }
    return candidateGroups;
  }

  static List<PlasterSurfaceLayout> _surfaceCandidates({
    required PlasterRoomShape shape,
    required PlasterRoomLine? line,
    required PlasterRoom room,
    required int? lineId,
    required bool isCeiling,
    required PlasterSheetDirection direction,
    required int width,
    required int height,
    required int area,
    required List<PlasterMaterialSize> materials,
    required String label,
  }) {
    final candidates = <PlasterSurfaceLayout>[];
    final seen = <String>{};
    final framingSpacing = isCeiling
        ? _ceilingFramingSpacing(shape)
        : _wallStudSpacing(shape, line);
    final framingOffset = isCeiling
        ? _ceilingFramingOffset(shape)
        : _wallStudOffset(shape, line);
    final fixingFaceWidth = isCeiling
        ? _ceilingFixingFaceWidth(shape)
        : _wallFixingFaceWidth(shape, line);
    final framingDetail =
        'framingSpacing=$framingSpacing, '
        'framingOffset=$framingOffset, '
        'fixingFaceWidth=$fixingFaceWidth';
    for (final material in materials) {
      final sheetWidth = convertLength(
        material.width,
        material.unitSystem,
        room.unitSystem,
      );
      final sheetHeight = convertLength(
        material.height,
        material.unitSystem,
        room.unitSystem,
      );
      final directionCandidates = _directionCandidates(
        direction: direction,
        sheetWidth: sheetWidth,
        sheetHeight: sheetHeight,
        surfaceWidth: width,
        surfaceHeight: height,
      );
      if (directionCandidates.isEmpty) {
        _logSurfaceCandidateDecision(
          label: label,
          material: material,
          direction: direction,
          decision: 'rejected',
          detail: 'no valid direction candidates, $framingDetail',
        );
      }
      for (final candidate in directionCandidates) {
        if (!isCeiling &&
            candidate.$1 == PlasterSheetDirection.vertical &&
            candidate.$3 < height) {
          _logSurfaceCandidateDecision(
            label: label,
            material: material,
            direction: candidate.$1,
            decision: 'rejected',
            detail:
                'vertical wall board shorter than wall height, '
                '$framingDetail',
          );
          continue;
        }
        final plans = _buildDeterministicPlacementPlans(
          shape: shape,
          line: line,
          width: width,
          height: height,
          sheetWidth: candidate.$2,
          sheetHeight: candidate.$3,
          minEdge: minEdgePiece(room.unitSystem),
          direction: candidate.$1,
          isCeiling: isCeiling,
        );
        if (plans.isEmpty) {
          _logSurfaceCandidateDecision(
            label: label,
            material: material,
            direction: candidate.$1,
            decision: 'rejected',
            detail:
                'no deterministic placement plans generated, '
                '$framingDetail',
          );
          continue;
        }
        var acceptedForCandidate = false;
        for (final plan in plans) {
          final packed = _packPieces(
            pieces: plan.$1,
            sheetWidth: candidate.$2,
            sheetHeight: candidate.$3,
            minReusableEdge: minEdgePiece(room.unitSystem),
          );
          final signature = [
            material.id,
            candidate.$1.name,
            packed.sheetCount,
            for (final piece in plan.$1)
              '${piece.x},${piece.y},${piece.width},${piece.height}',
          ].join('|');
          if (!seen.add(signature)) {
            continue;
          }
          acceptedForCandidate = true;
          final surface = PlasterSurfaceLayout(
            roomId: room.id,
            lineId: lineId,
            isCeiling: isCeiling,
            label: label,
            material: material,
            direction: candidate.$1,
            width: width,
            height: height,
            area: area,
            sheetsAcross: plan.$2,
            sheetsDown: plan.$3,
            sheetCount: packed.sheetCount,
            sheetCountWithWaste: packed.sheetCount,
            placements: plan.$1,
            sheetUsage: packed.sheetUsage,
            estimatedJointTapeLength: _estimateJointTapeLength(plan.$1),
            estimatedScrewCount: _estimateScrews(
              area: area,
              direction: candidate.$1,
              isCeiling: isCeiling,
            ),
            estimatedGlueKg: _estimateGlueKg(area, isCeiling),
            estimatedPlasterKg: _estimatePlasterKg(area, candidate.$1),
          );
          candidates.add(surface);
          _logSurfaceCandidateDecision(
            label: label,
            material: material,
            direction: candidate.$1,
            decision: 'accepted',
            detail:
                'sheetCount=${surface.sheetCount}, '
                'sheetsAcross=${surface.sheetsAcross}, '
                'sheetsDown=${surface.sheetsDown}, '
                'jointTape=${surface.estimatedJointTapeLength}, '
                '$framingDetail',
          );
        }
        if (!acceptedForCandidate) {
          _logSurfaceCandidateDecision(
            label: label,
            material: material,
            direction: candidate.$1,
            decision: 'rejected',
            detail: 'all generated plans were duplicates, $framingDetail',
          );
        }
      }
    }
    final filtered = isCeiling ? candidates : _pruneWallCandidates(candidates);
    final sorted = [...filtered]
      ..sort((left, right) {
        final leftCoverage = _layoutCoverage(left, room.unitSystem);
        final rightCoverage = _layoutCoverage(right, room.unitSystem);
        final sheetCountCompare = left.sheetCount.compareTo(right.sheetCount);
        if (sheetCountCompare != 0) {
          return sheetCountCompare;
        }
        final coverageCompare = leftCoverage.compareTo(rightCoverage);
        if (coverageCompare != 0) {
          return coverageCompare;
        }
        return left.estimatedJointTapeLength.compareTo(
          right.estimatedJointTapeLength,
        );
      });
    return sorted;
  }

  static void _logSurfaceCandidateDecision({
    required String label,
    required PlasterMaterialSize material,
    required PlasterSheetDirection direction,
    required String decision,
    required String detail,
  }) {
    if (!_debugSurfaceCandidateLogging) {
      return;
    }
    final message =
        'PLASTER_SURFACE_CANDIDATE '
        'surface="$label", '
        'material="${material.name}", '
        'direction=${direction.name}, '
        'decision=$decision, '
        'detail=$detail';
    try {
      Log.i(message);
    } catch (_) {
      debugPrint(message);
    }
  }

  static List<(List<PlasterSheetPlacement>, int, int)>
  _buildDeterministicPlacementPlans({
    required PlasterRoomShape shape,
    required PlasterRoomLine? line,
    required int width,
    required int height,
    required int sheetWidth,
    required int sheetHeight,
    required int minEdge,
    required PlasterSheetDirection direction,
    required bool isCeiling,
  }) {
    if (!isCeiling && direction == PlasterSheetDirection.vertical) {
      final row = _buildStudAlignedRow(
        surfaceWidth: width,
        sheetWidth: sheetWidth,
        minEdge: minEdge,
        framingSpacing: _wallStudSpacing(shape, line),
        framingOffset: _wallStudOffset(shape, line),
      );
      if (row == null) {
        return const [];
      }
      return [
        (
          [
            for (final piece in row.$1)
              PlasterSheetPlacement(
                x: piece.$1,
                y: 0,
                width: piece.$2,
                height: height,
              ),
          ],
          row.$1.length,
          1,
        ),
      ];
    }

    final rowHeights = _buildCourseHeights(
      surfaceHeight: height,
      sheetHeight: sheetHeight,
      minEdge: minEdge,
      horizontalWallStarter:
          !isCeiling && direction == PlasterSheetDirection.horizontal,
    );
    if (rowHeights == null || rowHeights.isEmpty) {
      return const [];
    }

    final framingSpacing = isCeiling
        ? _ceilingFramingSpacing(shape)
        : _wallStudSpacing(shape, line);
    final framingOffset = isCeiling
        ? _ceilingFramingOffset(shape)
        : _wallStudOffset(shape, line);
    final rowPatterns = _buildRowPatternOptions(
      surfaceWidth: width,
      sheetWidth: sheetWidth,
      minEdge: minEdge,
      framingSpacing: framingSpacing,
      framingOffset: framingOffset,
    );
    if (rowPatterns.isEmpty) {
      return const [];
    }

    final chosenRows = _selectRowPatterns(
      rowCount: rowHeights.length,
      rowPatterns: rowPatterns,
      staggerOffset: minEdge,
    );
    if (chosenRows == null) {
      return const [];
    }

    final placements = <PlasterSheetPlacement>[];
    var maxAcross = 0;
    var y = 0;
    for (var rowIndex = 0; rowIndex < rowHeights.length; rowIndex++) {
      final row = chosenRows[rowIndex];
      maxAcross = max(maxAcross, row.length);
      for (final piece in row) {
        placements.add(
          PlasterSheetPlacement(
            x: piece.$1,
            y: y,
            width: piece.$2,
            height: rowHeights[rowIndex],
          ),
        );
      }
      y += rowHeights[rowIndex];
    }
    return [(placements, maxAcross, rowHeights.length)];
  }

  static int _wallStudSpacing(PlasterRoomShape shape, PlasterRoomLine? line) =>
      line?.studSpacingOverride ?? shape.project?.wallStudSpacing ?? 6000;

  static int _wallStudOffset(PlasterRoomShape shape, PlasterRoomLine? line) =>
      line?.studOffsetOverride ?? shape.project?.wallStudOffset ?? 0;

  static int _wallFixingFaceWidth(
    PlasterRoomShape shape,
    PlasterRoomLine? line,
  ) =>
      line?.fixingFaceWidthOverride ??
      shape.project?.wallFixingFaceWidth ??
      450;

  static int _ceilingFramingSpacing(PlasterRoomShape shape) =>
      shape.room.ceilingFramingSpacingOverride ??
      shape.project?.ceilingFramingSpacing ??
      4500;

  static int _ceilingFramingOffset(PlasterRoomShape shape) =>
      shape.room.ceilingFramingOffsetOverride ??
      shape.project?.ceilingFramingOffset ??
      0;

  static int _ceilingFixingFaceWidth(PlasterRoomShape shape) =>
      shape.room.ceilingFixingFaceWidthOverride ??
      shape.project?.ceilingFixingFaceWidth ??
      450;

  static List<int>? _buildCourseHeights({
    required int surfaceHeight,
    required int sheetHeight,
    required int minEdge,
    required bool horizontalWallStarter,
  }) {
    if (surfaceHeight <= 0 || sheetHeight <= 0) {
      return null;
    }
    if (!horizontalWallStarter) {
      return _axisPieces(surfaceHeight, sheetHeight, minEdge);
    }
    final starterHeight = sheetHeight ~/ 2;
    if (starterHeight < minEdge || surfaceHeight < starterHeight) {
      return null;
    }
    if (surfaceHeight == starterHeight) {
      return [starterHeight];
    }
    final remainder = _axisPieces(
      surfaceHeight - starterHeight,
      sheetHeight,
      minEdge,
    );
    if (remainder == null) {
      return null;
    }
    return [starterHeight, ...remainder];
  }

  static List<List<(int, int)>> _buildRowPatternOptions({
    required int surfaceWidth,
    required int sheetWidth,
    required int minEdge,
    required int framingSpacing,
    required int framingOffset,
  }) {
    final patterns = <List<(int, int)>>[];
    final seen = <String>{};
    final studPositions = <int>{0, surfaceWidth};
    if (framingSpacing > 0) {
      var stud = framingOffset;
      while (stud < 0) {
        stud += framingSpacing;
      }
      for (; stud < surfaceWidth; stud += framingSpacing) {
        if (stud > 0) {
          studPositions.add(stud);
        }
      }
    }

    final orderedStuds = studPositions.toList()..sort();
    for (final startCut in orderedStuds) {
      if (startCut != 0 && (startCut < minEdge || startCut >= sheetWidth)) {
        continue;
      }
      final available = surfaceWidth - startCut;
      if (available <= 0) {
        continue;
      }
      final fullCount = available ~/ sheetWidth;
      final endPiece = available % sheetWidth;
      if (fullCount == 0 && startCut == 0 && surfaceWidth <= sheetWidth) {
        if (surfaceWidth >= minEdge) {
          patterns.add([(0, surfaceWidth)]);
        }
        continue;
      }
      if (endPiece != 0 && endPiece < minEdge) {
        continue;
      }

      final row = <(int, int)>[];
      var x = 0;
      if (startCut > 0) {
        row.add((x, startCut));
        x += startCut;
      }
      for (var i = 0; i < fullCount; i++) {
        row.add((x, sheetWidth));
        x += sheetWidth;
      }
      if (endPiece > 0) {
        row.add((x, endPiece));
        x += endPiece;
      }
      if (x != surfaceWidth) {
        continue;
      }
      final joints = _jointPositionsForPattern(row);
      final validJoints = joints.every(studPositions.contains);
      if (!validJoints) {
        continue;
      }
      final signature = row.map((piece) => '${piece.$1}:${piece.$2}').join(',');
      if (seen.add(signature)) {
        patterns.add(row);
      }
    }

    patterns.sort((left, right) {
      final leftCutCount = left.where((piece) => piece.$2 != sheetWidth).length;
      final rightCutCount = right
          .where((piece) => piece.$2 != sheetWidth)
          .length;
      if (leftCutCount != rightCutCount) {
        return leftCutCount.compareTo(rightCutCount);
      }
      final leftJoints = _jointPositionsForPattern(left).length;
      final rightJoints = _jointPositionsForPattern(right).length;
      if (leftJoints != rightJoints) {
        return leftJoints.compareTo(rightJoints);
      }
      final leftWaste = left.fold<int>(
        0,
        (sum, piece) =>
            sum + (piece.$2 == sheetWidth ? 0 : sheetWidth - piece.$2),
      );
      final rightWaste = right.fold<int>(
        0,
        (sum, piece) =>
            sum + (piece.$2 == sheetWidth ? 0 : sheetWidth - piece.$2),
      );
      return leftWaste.compareTo(rightWaste);
    });
    return patterns;
  }

  static List<List<(int, int)>>? _selectRowPatterns({
    required int rowCount,
    required List<List<(int, int)>> rowPatterns,
    required int staggerOffset,
  }) {
    List<List<(int, int)>>? best;

    void search(int index, List<List<(int, int)>> chosen) {
      if (best != null) {
        return;
      }
      if (index == rowCount) {
        best = [...chosen];
        return;
      }
      for (final pattern in rowPatterns) {
        if (chosen.isNotEmpty &&
            _rowPatternStaggerViolation(chosen.last, pattern, staggerOffset)) {
          continue;
        }
        search(index + 1, [...chosen, pattern]);
        if (best != null) {
          return;
        }
      }
    }

    search(0, const []);
    return best;
  }

  static bool _rowPatternStaggerViolation(
    List<(int, int)> left,
    List<(int, int)> right,
    int staggerOffset,
  ) {
    final leftJoints = _jointPositionsForPattern(left);
    final rightJoints = _jointPositionsForPattern(right);
    for (final a in leftJoints) {
      for (final b in rightJoints) {
        if ((a - b).abs() < staggerOffset) {
          return true;
        }
      }
    }
    return false;
  }

  static List<int> _jointPositionsForPattern(List<(int, int)> row) => [
    for (var i = 0; i < row.length - 1; i++) row[i].$1 + row[i].$2,
  ];

  static (List<(int, int)>, int)? _buildStudAlignedRow({
    required int surfaceWidth,
    required int sheetWidth,
    required int minEdge,
    required int framingSpacing,
    required int framingOffset,
  }) {
    final rows = _buildRowPatternOptions(
      surfaceWidth: surfaceWidth,
      sheetWidth: sheetWidth,
      minEdge: minEdge,
      framingSpacing: framingSpacing,
      framingOffset: framingOffset,
    );
    if (rows.isEmpty) {
      return null;
    }
    return (rows.first, rows.first.length);
  }

  static List<PlasterSurfaceLayout> _pruneWallCandidates(
    List<PlasterSurfaceLayout> candidates,
  ) {
    final filtered = <PlasterSurfaceLayout>[];
    for (final candidate in candidates) {
      final candidateButtJoints = _buttJointLength(candidate);
      final dominated = candidates.any((other) {
        if (identical(candidate, other)) {
          return false;
        }
        final otherButtJoints = _buttJointLength(other);
        final noWorse =
            other.sheetCount <= candidate.sheetCount &&
            other.estimatedJointTapeLength <=
                candidate.estimatedJointTapeLength &&
            otherButtJoints <= candidateButtJoints;
        final strictlyBetter =
            other.sheetCount < candidate.sheetCount ||
            other.estimatedJointTapeLength <
                candidate.estimatedJointTapeLength ||
            otherButtJoints < candidateButtJoints;
        if (!noWorse || !strictlyBetter) {
          return false;
        }
        if (candidate.direction == PlasterSheetDirection.vertical &&
            other.direction == PlasterSheetDirection.horizontal) {
          return true;
        }
        return other.direction == candidate.direction;
      });
      if (!dominated) {
        filtered.add(candidate);
      }
    }
    return filtered;
  }

  static _ProjectLayoutState _optimizeProjectLayouts(
    List<List<PlasterSurfaceLayout>> candidateGroups,
    List<PlasterRoomShape> roomShapes, {
    _PlasterSearchBudget? budget,
  }) {
    if (candidateGroups.isEmpty) {
      return const _ProjectLayoutState(
        layouts: [],
        score: _ProjectLayoutScore(
          sheetCount: 0,
          wasteArea: 0,
          fragmentationPenalty: 0,
          reusableArea: 0,
          jointTapeLength: 0,
          buttJointLength: 0,
          cutPieceCount: 0,
          highJointLength: 0,
          smallPieceCount: 0,
          verticalWallCount: 0,
        ),
      );
    }
    const beamWidth = 12;
    var beam = <_ProjectLayoutState>[
      const _ProjectLayoutState(
        layouts: [],
        score: _ProjectLayoutScore(
          sheetCount: 0,
          wasteArea: 0,
          fragmentationPenalty: 0,
          reusableArea: 0,
          jointTapeLength: 0,
          buttJointLength: 0,
          cutPieceCount: 0,
          highJointLength: 0,
          smallPieceCount: 0,
          verticalWallCount: 0,
        ),
      ),
    ];

    for (final group in candidateGroups) {
      final nextBeam = <_ProjectLayoutState>[];
      var stopRequested = false;
      for (final state in beam) {
        for (final candidate in group) {
          if (budget?.tick() ?? false) {
            stopRequested = true;
            break;
          }
          budget?.maybeReportProgress();
          final layouts = [...state.layouts, candidate];
          nextBeam.add(
            _ProjectLayoutState(
              layouts: layouts,
              score: _evaluateProjectLayouts(
                layouts,
                roomShapes,
                budget: budget,
              ),
            ),
          );
        }
        if (stopRequested) {
          break;
        }
      }
      final beamSource = nextBeam.isEmpty ? beam : nextBeam
        ..sort((left, right) {
          if (_isBetterProjectScore(left.score, right.score, budget?.scoring)) {
            return -1;
          }
          if (_isBetterProjectScore(right.score, left.score, budget?.scoring)) {
            return 1;
          }
          return 0;
        });
      beam = beamSource.take(beamWidth).toList();
      if (beam.first.layouts.length == candidateGroups.length) {
        budget?.maybeReport(beam.first.layouts, beam.first.score);
      }
      if (stopRequested) {
        break;
      }
    }
    final best = beam.first;
    budget?.maybeReportProgress(force: true);
    budget?.maybeReport(best.layouts, best.score, force: true);
    return best;
  }

  static int _layoutCoverage(
    PlasterSurfaceLayout layout,
    PreferredUnitSystem roomUnitSystem,
  ) {
    final sheetWidth = convertLength(
      layout.material.width,
      layout.material.unitSystem,
      roomUnitSystem,
    );
    final sheetHeight = convertLength(
      layout.material.height,
      layout.material.unitSystem,
      roomUnitSystem,
    );
    return sheetWidth * sheetHeight * layout.sheetCount;
  }

  static _ProjectLayoutScore _evaluateProjectLayouts(
    List<PlasterSurfaceLayout> layouts,
    List<PlasterRoomShape> roomShapes, {
    _PlasterSearchBudget? budget,
  }) {
    final groupedPieces = <String, List<PlasterSheetPlacement>>{};
    final groupedSheetSizes = <String, (int, int)>{};
    var sheetCount = 0;
    var wasteArea = 0;
    var fragmentationPenalty = 0;
    var reusableArea = 0;
    var jointTapeLength = 0;
    var buttJointLength = 0;
    var cutPieceCount = 0;
    var highJointLength = 0;
    var smallPieceCount = 0;
    var verticalWallCount = 0;

    for (final layout in layouts) {
      final roomUnitSystem = _unitSystemForArea(layout, roomShapes);
      jointTapeLength += layout.estimatedJointTapeLength;
      buttJointLength += _buttJointLength(layout);
      cutPieceCount += _countCutPieces(layout, roomUnitSystem);
      highJointLength += _highJointLength(layout, roomUnitSystem);
      smallPieceCount += _smallPieceCount(layout);
      if (!layout.isCeiling &&
          layout.direction == PlasterSheetDirection.vertical) {
        verticalWallCount++;
      }
      final key =
          '${layout.material.id}:${layout.material.unitSystem.name}:'
          '${layout.material.width}:${layout.material.height}';
      final pieces = groupedPieces.putIfAbsent(key, () => []);
      for (final piece in layout.placements) {
        pieces.add(
          PlasterSheetPlacement(
            x: 0,
            y: 0,
            width: convertLength(
              piece.width,
              roomUnitSystem,
              layout.material.unitSystem,
            ),
            height: convertLength(
              piece.height,
              roomUnitSystem,
              layout.material.unitSystem,
            ),
          ),
        );
      }
      groupedSheetSizes.putIfAbsent(
        key,
        () => (layout.material.width, layout.material.height),
      );
    }

    for (final entry in groupedPieces.entries) {
      final sheetSize = groupedSheetSizes[entry.key]!;
      final packed = _packPieces(
        pieces: entry.value,
        sheetWidth: sheetSize.$1,
        sheetHeight: sheetSize.$2,
        minReusableEdge: minEdgePiece(
          entry.value.isEmpty
              ? PreferredUnitSystem.metric
              : _unitSystemForMaterialKey(entry.key),
        ),
        budget: budget,
      );
      sheetCount += packed.sheetCount;
      wasteArea += packed.wasteArea;
      fragmentationPenalty += packed.fragmentationPenalty;
      reusableArea += packed.reusableArea;
    }

    return _ProjectLayoutScore(
      sheetCount: sheetCount,
      wasteArea: wasteArea,
      fragmentationPenalty: fragmentationPenalty,
      reusableArea: reusableArea,
      jointTapeLength: jointTapeLength,
      buttJointLength: buttJointLength,
      cutPieceCount: cutPieceCount,
      highJointLength: highJointLength,
      smallPieceCount: smallPieceCount,
      verticalWallCount: verticalWallCount,
    );
  }

  static bool _isBetterProjectScore(
    _ProjectLayoutScore left,
    _ProjectLayoutScore right,
    PlasterLayoutScoring? scoring,
  ) {
    final weights = scoring ?? const PlasterLayoutScoring.defaults();
    final leftTotal =
        left.sheetCount * weights.extraSheetWeight +
        left.jointTapeLength * weights.jointLengthWeight +
        left.buttJointLength * weights.buttJointWeight +
        left.cutPieceCount * weights.cutPieceWeight +
        left.highJointLength * weights.highJointWeight +
        left.smallPieceCount * weights.smallPieceWeight +
        left.fragmentationPenalty * weights.fragmentationWeight +
        left.verticalWallCount * weights.verticalWallPenaltyWeight -
        left.reusableArea;
    final rightTotal =
        right.sheetCount * weights.extraSheetWeight +
        right.jointTapeLength * weights.jointLengthWeight +
        right.buttJointLength * weights.buttJointWeight +
        right.cutPieceCount * weights.cutPieceWeight +
        right.highJointLength * weights.highJointWeight +
        right.smallPieceCount * weights.smallPieceWeight +
        right.fragmentationPenalty * weights.fragmentationWeight +
        right.verticalWallCount * weights.verticalWallPenaltyWeight -
        right.reusableArea;
    if (leftTotal != rightTotal) {
      return leftTotal < rightTotal;
    }
    if (left.sheetCount != right.sheetCount) {
      return left.sheetCount < right.sheetCount;
    }
    return left.wasteArea < right.wasteArea;
  }

  static List<(PlasterSheetDirection, int, int)> _directionCandidates({
    required PlasterSheetDirection direction,
    required int sheetWidth,
    required int sheetHeight,
    required int surfaceWidth,
    required int surfaceHeight,
  }) {
    final shortSide = min(sheetWidth, sheetHeight);
    final longSide = max(sheetWidth, sheetHeight);
    final horizontal = (PlasterSheetDirection.horizontal, longSide, shortSide);
    final vertical = (PlasterSheetDirection.vertical, shortSide, longSide);
    final verticalSingleSheetAllowed =
        shortSide >= surfaceWidth && longSide >= surfaceHeight;
    return switch (direction) {
      PlasterSheetDirection.horizontal => [horizontal],
      PlasterSheetDirection.vertical =>
        verticalSingleSheetAllowed ? [vertical] : const [],
      PlasterSheetDirection.auto =>
        verticalSingleSheetAllowed ? [horizontal, vertical] : [horizontal],
    };
  }

  static List<int>? _axisPieces(
    int surfaceLength,
    int sheetLength,
    int minEdge,
  ) {
    if (surfaceLength <= 0) {
      return null;
    }
    if (surfaceLength <= sheetLength) {
      return surfaceLength < minEdge ? null : [surfaceLength];
    }
    final preferredEdge = max(minEdge, sheetLength ~/ 2);
    List<int>? best;
    (int, int, int, int)? bestScore;

    void consider(List<int> candidate) {
      if (candidate.any((piece) => piece < minEdge || piece > sheetLength)) {
        return;
      }
      final preferredViolations = candidate
          .where((piece) => piece != sheetLength && piece < preferredEdge)
          .length;
      final cutPieceCount = candidate
          .where((piece) => piece != sheetLength)
          .length;
      final fullPieceCount = candidate
          .where((piece) => piece == sheetLength)
          .length;
      final minPiece = candidate.reduce(min);
      final score = (
        preferredViolations,
        candidate.length,
        cutPieceCount,
        -fullPieceCount,
      );
      if (best == null ||
          score.$1 < bestScore!.$1 ||
          (score.$1 == bestScore!.$1 && score.$2 < bestScore!.$2) ||
          (score.$1 == bestScore!.$1 &&
              score.$2 == bestScore!.$2 &&
              score.$3 < bestScore!.$3) ||
          (score.$1 == bestScore!.$1 &&
              score.$2 == bestScore!.$2 &&
              score.$3 == bestScore!.$3 &&
              score.$4 < bestScore!.$4) ||
          (score == bestScore && minPiece > best!.reduce(min))) {
        best = candidate;
        bestScore = score;
      }
    }

    for (
      var fullCount = surfaceLength ~/ sheetLength;
      fullCount >= 0;
      fullCount--
    ) {
      final remainder = surfaceLength - fullCount * sheetLength;
      if (remainder == 0) {
        consider(List<int>.filled(fullCount, sheetLength));
        continue;
      }
      if (remainder >= minEdge && remainder <= sheetLength) {
        consider([...List<int>.filled(fullCount, sheetLength), remainder]);
      }
      if (remainder >= minEdge * 2 && remainder <= sheetLength * 2) {
        final firstPiece = remainder ~/ 2;
        final secondPiece = remainder - firstPiece;
        consider([
          firstPiece,
          ...List<int>.filled(fullCount, sheetLength),
          secondPiece,
        ]);
      }
    }
    return best;
  }

  static int _estimateJointTapeLength(List<PlasterSheetPlacement> placements) {
    var total = 0;
    for (var i = 0; i < placements.length; i++) {
      final left = placements[i];
      for (var j = i + 1; j < placements.length; j++) {
        final right = placements[j];
        if (left.x + left.width == right.x || right.x + right.width == left.x) {
          total += _overlapLength(left.y, left.height, right.y, right.height);
        }
        if (left.y + left.height == right.y ||
            right.y + right.height == left.y) {
          total += _overlapLength(left.x, left.width, right.x, right.width);
        }
      }
    }
    return total;
  }

  static int _buttJointLength(PlasterSurfaceLayout layout) {
    var total = 0;
    for (var i = 0; i < layout.placements.length; i++) {
      final left = layout.placements[i];
      for (var j = i + 1; j < layout.placements.length; j++) {
        final right = layout.placements[j];
        final sharesVerticalEdge =
            left.x + left.width == right.x || right.x + right.width == left.x;
        final sharesHorizontalEdge =
            left.y + left.height == right.y || right.y + right.height == left.y;
        if (layout.direction == PlasterSheetDirection.horizontal &&
            sharesVerticalEdge) {
          total += _overlapLength(left.y, left.height, right.y, right.height);
        }
        if (layout.direction == PlasterSheetDirection.vertical &&
            sharesHorizontalEdge) {
          total += _overlapLength(left.x, left.width, right.x, right.width);
        }
      }
    }
    return total;
  }

  static _PackingResult _packPieces({
    required List<PlasterSheetPlacement> pieces,
    required int sheetWidth,
    required int sheetHeight,
    required int minReusableEdge,
    _PlasterSearchBudget? budget,
  }) {
    if (pieces.isEmpty) {
      return const _PackingResult(
        sheetCount: 0,
        wasteArea: 0,
        usedArea: 0,
        fragmentationPenalty: 0,
        reusableArea: 0,
        sheetUsage: [],
      );
    }

    final sorted = [...pieces]
      ..sort((left, right) {
        final areaCompare = (right.width * right.height).compareTo(
          left.width * left.height,
        );
        if (areaCompare != 0) {
          return areaCompare;
        }
        final heightCompare = right.height.compareTo(left.height);
        if (heightCompare != 0) {
          return heightCompare;
        }
        final widthCompare = right.width.compareTo(left.width);
        if (widthCompare != 0) {
          return widthCompare;
        }
        return 0;
      });

    const beamWidth = 24;
    const maxChoicesPerPiece = 4;
    var beam = <_PackingState>[
      const _PackingState(
        sheets: [],
        usedArea: 0,
        score: _ProjectLayoutScore(
          sheetCount: 0,
          wasteArea: 0,
          fragmentationPenalty: 0,
          reusableArea: 0,
          jointTapeLength: 0,
          buttJointLength: 0,
          cutPieceCount: 0,
          highJointLength: 0,
          smallPieceCount: 0,
          verticalWallCount: 0,
        ),
      ),
    ];

    for (final piece in sorted) {
      if (budget?.isExpired ?? false) {
        budget?.timedOut = true;
        break;
      }
      final nextBeam = <_PackingState>[];
      for (final state in beam) {
        final choices = _placementChoices(
          state: state,
          pieceWidth: piece.width,
          pieceHeight: piece.height,
          sheetWidth: sheetWidth,
          sheetHeight: sheetHeight,
          minReusableEdge: minReusableEdge,
        );
        for (final choice in choices.take(maxChoicesPerPiece)) {
          final nextState = _applyPlacementChoice(
            state: state,
            choice: choice,
            sheetWidth: sheetWidth,
            sheetHeight: sheetHeight,
            minReusableEdge: minReusableEdge,
          );
          if (nextState != null) {
            nextBeam.add(nextState);
          }
        }
      }
      if (nextBeam.isEmpty) {
        final sheetArea = sheetWidth * sheetHeight;
        final usedArea = sorted.fold<int>(
          0,
          (sum, value) => sum + value.width * value.height,
        );
        final fallbackSheets = max(
          1,
          sorted.fold<int>(0, (sum, value) => sum + 1),
        );
        return _PackingResult(
          sheetCount: fallbackSheets,
          wasteArea: max(0, fallbackSheets * sheetArea - usedArea),
          usedArea: usedArea,
          fragmentationPenalty: 0,
          reusableArea: 0,
          sheetUsage: [],
        );
      }
      nextBeam.sort((left, right) {
        if (_isBetterProjectScore(left.score, right.score, budget?.scoring)) {
          return -1;
        }
        if (_isBetterProjectScore(right.score, left.score, budget?.scoring)) {
          return 1;
        }
        return 0;
      });
      beam = nextBeam.take(beamWidth).toList();
    }

    final best = beam.first;
    return _PackingResult(
      sheetCount: best.score.sheetCount,
      wasteArea: best.score.wasteArea,
      usedArea: best.usedArea,
      fragmentationPenalty: best.score.fragmentationPenalty,
      reusableArea: best.score.reusableArea,
      sheetUsage: [
        for (final sheet in best.sheets)
          PlasterSheetUsage(
            usedPieces: sheet.usedPieces,
            offcuts: [
              for (final rect in sheet.freeRects)
                PlasterSheetOffcut(
                  x: rect.x,
                  y: rect.y,
                  width: rect.width,
                  height: rect.height,
                  reusable:
                      rect.width >= minReusableEdge &&
                      rect.height >= minReusableEdge,
                  reusedLater: rect.reusedLater,
                ),
            ],
            sheetWidth: sheetWidth,
            sheetHeight: sheetHeight,
          ),
      ],
    );
  }

  static List<_ExplorerPackedSheet> _packSurfacePiecesForExplorer({
    required List<_PackableSurfacePiece> pieces,
    required int sheetWidth,
    required int sheetHeight,
    required int minReusableEdge,
  }) {
    if (pieces.isEmpty) {
      return const [];
    }

    final sorted = [...pieces]
      ..sort((left, right) {
        final areaCompare = (right.width * right.height).compareTo(
          left.width * left.height,
        );
        if (areaCompare != 0) {
          return areaCompare;
        }
        final heightCompare = right.height.compareTo(left.height);
        if (heightCompare != 0) {
          return heightCompare;
        }
        return right.width.compareTo(left.width);
      });

    var sheets = <_ExplorerPackedSheet>[];
    for (final piece in sorted) {
      final state = _applyExplorerPiece(
        sheets: sheets,
        piece: piece,
        sheetWidth: sheetWidth,
        sheetHeight: sheetHeight,
        minReusableEdge: minReusableEdge,
      );
      sheets = state;
    }
    return sheets;
  }

  static List<_ExplorerPackedSheet> _applyExplorerPiece({
    required List<_ExplorerPackedSheet> sheets,
    required _PackableSurfacePiece piece,
    required int sheetWidth,
    required int sheetHeight,
    required int minReusableEdge,
  }) {
    final choices =
        <
          ({
            int sheetIndex,
            int rectIndex,
            int pieceWidth,
            int pieceHeight,
            List<_FreeRect> freeRects,
            int leftoverArea,
            int fragmentationPenalty,
            int reusableArea,
          })
        >[];

    final orientations = <(int, int)>[
      (piece.width, piece.height),
      if (piece.width != piece.height) (piece.height, piece.width),
    ];

    for (var sheetIndex = 0; sheetIndex < sheets.length; sheetIndex++) {
      final sheet = sheets[sheetIndex];
      for (var rectIndex = 0; rectIndex < sheet.freeRects.length; rectIndex++) {
        final rect = sheet.freeRects[rectIndex];
        for (final orientation in orientations) {
          if (orientation.$1 > rect.width || orientation.$2 > rect.height) {
            continue;
          }
          for (final splitRects in _guillotineSplitVariants(
            rect: rect,
            pieceWidth: orientation.$1,
            pieceHeight: orientation.$2,
          )) {
            final pruned = [...splitRects];
            _pruneFreeRects(pruned);
            choices.add((
              sheetIndex: sheetIndex,
              rectIndex: rectIndex,
              pieceWidth: orientation.$1,
              pieceHeight: orientation.$2,
              freeRects: pruned,
              leftoverArea: rect.area - orientation.$1 * orientation.$2,
              fragmentationPenalty: _fragmentationPenalty(
                pruned,
                minReusableEdge,
              ),
              reusableArea: _reusableArea(pruned, minReusableEdge),
            ));
          }
        }
      }
    }

    for (final orientation in orientations) {
      if (orientation.$1 > sheetWidth || orientation.$2 > sheetHeight) {
        continue;
      }
      for (final splitRects in _guillotineSplitVariants(
        rect: _FreeRect(0, 0, sheetWidth, sheetHeight),
        pieceWidth: orientation.$1,
        pieceHeight: orientation.$2,
      )) {
        final pruned = [...splitRects];
        _pruneFreeRects(pruned);
        choices.add((
          sheetIndex: sheets.length,
          rectIndex: -1,
          pieceWidth: orientation.$1,
          pieceHeight: orientation.$2,
          freeRects: pruned,
          leftoverArea:
              sheetWidth * sheetHeight - orientation.$1 * orientation.$2,
          fragmentationPenalty: _fragmentationPenalty(pruned, minReusableEdge),
          reusableArea: _reusableArea(pruned, minReusableEdge),
        ));
      }
    }

    choices.sort((left, right) {
      final newSheetCompare = left.sheetIndex.compareTo(right.sheetIndex);
      if (newSheetCompare != 0) {
        return newSheetCompare;
      }
      final leftoverCompare = left.leftoverArea.compareTo(right.leftoverArea);
      if (leftoverCompare != 0) {
        return leftoverCompare;
      }
      final fragmentationCompare = left.fragmentationPenalty.compareTo(
        right.fragmentationPenalty,
      );
      if (fragmentationCompare != 0) {
        return fragmentationCompare;
      }
      return right.reusableArea.compareTo(left.reusableArea);
    });

    final choice = choices.first;
    final nextSheets = [for (final sheet in sheets) sheet.copy()];
    if (choice.sheetIndex == nextSheets.length) {
      nextSheets.add(const _ExplorerPackedSheet(freeRects: [], usedPieces: []));
    }
    final targetSheet = nextSheets[choice.sheetIndex];
    final freeRects = [for (final rect in targetSheet.freeRects) rect];
    final consumedRect = choice.rectIndex >= 0
        ? freeRects.removeAt(choice.rectIndex)
        : _FreeRect(0, 0, sheetWidth, sheetHeight);
    final offcutWasReused = choice.rectIndex >= 0 || consumedRect.reusedLater;
    freeRects.addAll([
      for (final rect in choice.freeRects)
        _FreeRect(
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          reusedLater: offcutWasReused,
        ),
    ]);
    nextSheets[choice.sheetIndex] = _ExplorerPackedSheet(
      freeRects: freeRects,
      usedPieces: [
        ...targetSheet.usedPieces,
        PlasterProjectSheetPiece(
          x: consumedRect.x,
          y: consumedRect.y,
          width: choice.pieceWidth,
          height: choice.pieceHeight,
          surfaceLabel: piece.surfaceLabel,
          reusedOffcut: choice.rectIndex >= 0,
          sourceSheetIndex: choice.rectIndex >= 0 ? choice.sheetIndex : null,
        ),
      ],
    );
    return nextSheets;
  }

  static List<_PlacementChoice> _placementChoices({
    required _PackingState state,
    required int pieceWidth,
    required int pieceHeight,
    required int sheetWidth,
    required int sheetHeight,
    required int minReusableEdge,
  }) {
    final choices = <_PlacementChoice>[];
    final orientations = <(int, int)>[
      (pieceWidth, pieceHeight),
      if (pieceWidth != pieceHeight) (pieceHeight, pieceWidth),
    ];

    for (var sheetIndex = 0; sheetIndex < state.sheets.length; sheetIndex++) {
      final sheet = state.sheets[sheetIndex];
      for (var rectIndex = 0; rectIndex < sheet.freeRects.length; rectIndex++) {
        final rect = sheet.freeRects[rectIndex];
        for (final orientation in orientations) {
          if (orientation.$1 > rect.width || orientation.$2 > rect.height) {
            continue;
          }
          for (final splitRects in _guillotineSplitVariants(
            rect: rect,
            pieceWidth: orientation.$1,
            pieceHeight: orientation.$2,
          )) {
            final pruned = [...splitRects];
            _pruneFreeRects(pruned);
            choices.add(
              _PlacementChoice(
                sheetIndex: sheetIndex,
                rectIndex: rectIndex,
                pieceWidth: orientation.$1,
                pieceHeight: orientation.$2,
                freeRects: pruned,
                leftoverArea: rect.area - orientation.$1 * orientation.$2,
                fragmentationPenalty: _fragmentationPenalty(
                  pruned,
                  minReusableEdge,
                ),
                reusableArea: _reusableArea(pruned, minReusableEdge),
              ),
            );
          }
        }
      }
    }

    for (final orientation in orientations) {
      if (orientation.$1 > sheetWidth || orientation.$2 > sheetHeight) {
        continue;
      }
      for (final splitRects in _guillotineSplitVariants(
        rect: _FreeRect(0, 0, sheetWidth, sheetHeight),
        pieceWidth: orientation.$1,
        pieceHeight: orientation.$2,
      )) {
        final pruned = [...splitRects];
        _pruneFreeRects(pruned);
        choices.add(
          _PlacementChoice(
            sheetIndex: state.sheets.length,
            rectIndex: -1,
            pieceWidth: orientation.$1,
            pieceHeight: orientation.$2,
            freeRects: pruned,
            leftoverArea:
                sheetWidth * sheetHeight - orientation.$1 * orientation.$2,
            fragmentationPenalty: _fragmentationPenalty(
              pruned,
              minReusableEdge,
            ),
            reusableArea: _reusableArea(pruned, minReusableEdge),
          ),
        );
      }
    }

    choices.sort((left, right) {
      final newSheetCompare = left.sheetIndex.compareTo(right.sheetIndex);
      if (newSheetCompare != 0) {
        return newSheetCompare;
      }
      final leftoverCompare = left.leftoverArea.compareTo(right.leftoverArea);
      if (leftoverCompare != 0) {
        return leftoverCompare;
      }
      final fragmentationCompare = left.fragmentationPenalty.compareTo(
        right.fragmentationPenalty,
      );
      if (fragmentationCompare != 0) {
        return fragmentationCompare;
      }
      return right.reusableArea.compareTo(left.reusableArea);
    });
    return choices;
  }

  static _PackingState? _applyPlacementChoice({
    required _PackingState state,
    required _PlacementChoice choice,
    required int sheetWidth,
    required int sheetHeight,
    required int minReusableEdge,
  }) {
    final sheets = [for (final sheet in state.sheets) sheet.copy()];
    if (choice.sheetIndex > sheets.length) {
      return null;
    }
    if (choice.sheetIndex == sheets.length) {
      sheets.add(
        const _PackedSheet(freeRects: [], usedPieces: [], usedArea: 0),
      );
    }

    final targetSheet = sheets[choice.sheetIndex];
    final freeRects = [for (final rect in targetSheet.freeRects) rect];
    if (choice.rectIndex >= freeRects.length) {
      return null;
    }
    final consumedRect = choice.rectIndex >= 0
        ? freeRects.removeAt(choice.rectIndex)
        : _FreeRect(0, 0, sheetWidth, sheetHeight);
    freeRects.addAll(choice.freeRects);
    sheets[choice.sheetIndex] = _PackedSheet(
      freeRects: freeRects,
      usedPieces: [
        ...targetSheet.usedPieces,
        PlasterSheetUsagePiece(
          x: consumedRect.x,
          y: consumedRect.y,
          width: choice.pieceWidth,
          height: choice.pieceHeight,
        ),
      ],
      usedArea: targetSheet.usedArea + choice.pieceWidth * choice.pieceHeight,
    );

    final usedArea = state.usedArea + choice.pieceWidth * choice.pieceHeight;
    final sheetArea = sheetWidth * sheetHeight;
    final fragmentationPenalty = sheets.fold<int>(
      0,
      (sum, sheet) =>
          sum + _fragmentationPenalty(sheet.freeRects, minReusableEdge),
    );
    final reusableArea = sheets.fold<int>(
      0,
      (sum, sheet) => sum + _reusableArea(sheet.freeRects, minReusableEdge),
    );
    return _PackingState(
      sheets: sheets,
      usedArea: usedArea,
      score: _ProjectLayoutScore(
        sheetCount: sheets.length,
        wasteArea: max(0, sheets.length * sheetArea - usedArea),
        fragmentationPenalty: fragmentationPenalty,
        reusableArea: reusableArea,
        jointTapeLength: 0,
        buttJointLength: 0,
        cutPieceCount: 0,
        highJointLength: 0,
        smallPieceCount: 0,
        verticalWallCount: 0,
      ),
    );
  }

  static List<List<_FreeRect>> _guillotineSplitVariants({
    required _FreeRect rect,
    required int pieceWidth,
    required int pieceHeight,
  }) {
    final variants = <List<_FreeRect>>[];
    final rightWidth = rect.width - pieceWidth;
    final bottomHeight = rect.height - pieceHeight;

    final cutVerticalFirst = <_FreeRect>[
      if (rightWidth > 0)
        _FreeRect(rect.x + pieceWidth, rect.y, rightWidth, rect.height),
      if (bottomHeight > 0)
        _FreeRect(rect.x, rect.y + pieceHeight, pieceWidth, bottomHeight),
    ];
    final cutHorizontalFirst = <_FreeRect>[
      if (rightWidth > 0)
        _FreeRect(rect.x + pieceWidth, rect.y, rightWidth, pieceHeight),
      if (bottomHeight > 0)
        _FreeRect(rect.x, rect.y + pieceHeight, rect.width, bottomHeight),
    ];

    variants.add(cutVerticalFirst);
    final horizontalSignature = cutHorizontalFirst
        .map((rect) => '${rect.x},${rect.y},${rect.width},${rect.height}')
        .join('|');
    final verticalSignature = cutVerticalFirst
        .map((rect) => '${rect.x},${rect.y},${rect.width},${rect.height}')
        .join('|');
    if (horizontalSignature != verticalSignature) {
      variants.add(cutHorizontalFirst);
    }
    return variants;
  }

  static int _fragmentationPenalty(
    List<_FreeRect> freeRects,
    int minReusableEdge,
  ) => freeRects.fold<int>(0, (sum, rect) {
    final reusable =
        rect.width >= minReusableEdge && rect.height >= minReusableEdge;
    if (!reusable) {
      return sum + rect.area;
    }
    return sum + max(0, minReusableEdge * minReusableEdge - rect.area);
  });

  static int _reusableArea(List<_FreeRect> freeRects, int minReusableEdge) =>
      freeRects.fold<int>(0, (sum, rect) {
        final reusable =
            rect.width >= minReusableEdge && rect.height >= minReusableEdge;
        return sum + (reusable ? rect.area : 0);
      });

  static PreferredUnitSystem _unitSystemForMaterialKey(String key) =>
      key.split(':')[1] == PreferredUnitSystem.imperial.name
      ? PreferredUnitSystem.imperial
      : PreferredUnitSystem.metric;

  static void _pruneFreeRects(List<_FreeRect> freeRects) {
    freeRects.removeWhere((rect) => rect.width <= 0 || rect.height <= 0);
    for (var i = freeRects.length - 1; i >= 0; i--) {
      final current = freeRects[i];
      for (var j = 0; j < freeRects.length; j++) {
        if (i == j) {
          continue;
        }
        final other = freeRects[j];
        if (current.isContainedIn(other)) {
          freeRects.removeAt(i);
          break;
        }
      }
    }
  }

  static int _overlapLength(int startA, int lengthA, int startB, int lengthB) {
    final overlapStart = max(startA, startB);
    final overlapEnd = min(startA + lengthA, startB + lengthB);
    return max(0, overlapEnd - overlapStart);
  }

  static int _countCutPieces(
    PlasterSurfaceLayout layout,
    PreferredUnitSystem roomUnitSystem,
  ) {
    final sheetWidth = layout.direction == PlasterSheetDirection.vertical
        ? min(layout.material.width, layout.material.height)
        : max(layout.material.width, layout.material.height);
    final sheetHeight = layout.direction == PlasterSheetDirection.vertical
        ? max(layout.material.width, layout.material.height)
        : min(layout.material.width, layout.material.height);
    final naturalWidth = convertLength(
      sheetWidth,
      layout.material.unitSystem,
      roomUnitSystem,
    );
    final naturalHeight = convertLength(
      sheetHeight,
      layout.material.unitSystem,
      roomUnitSystem,
    );
    var cutPieces = 0;
    for (final placement in layout.placements) {
      if (placement.width != naturalWidth ||
          placement.height != naturalHeight) {
        cutPieces++;
      }
    }
    return cutPieces;
  }

  static int _highJointLength(
    PlasterSurfaceLayout layout,
    PreferredUnitSystem roomUnitSystem,
  ) {
    if (layout.isCeiling) {
      return 0;
    }
    final threshold = roomUnitSystem == PreferredUnitSystem.metric
        ? 15000
        : 59055;
    var total = 0;
    for (var i = 0; i < layout.placements.length; i++) {
      final left = layout.placements[i];
      for (var j = i + 1; j < layout.placements.length; j++) {
        final right = layout.placements[j];
        if (left.y + left.height == right.y ||
            right.y + right.height == left.y) {
          final jointY = left.y + left.height == right.y ? right.y : left.y;
          if (jointY > threshold) {
            total += _overlapLength(left.x, left.width, right.x, right.width);
          }
        }
      }
    }
    return total;
  }

  static int _smallPieceCount(PlasterSurfaceLayout layout) {
    final unitSystem = layout.material.unitSystem;
    final warningEdge = unitSystem == PreferredUnitSystem.metric ? 6000 : 23622;
    return layout.placements.fold<int>(0, (sum, piece) {
      final small = piece.width < warningEdge || piece.height < warningEdge;
      return sum + (small ? 1 : 0);
    });
  }

  static int _estimateScrews({
    required int area,
    required PlasterSheetDirection direction,
    required bool isCeiling,
  }) {
    final areaSqM = area / (metricUnitsPerMm * metricUnitsPerMm) / 1000000;
    final perHundredSqM = isCeiling
        ? direction == PlasterSheetDirection.vertical
              ? 1150
              : 820
        : 620;
    return max(1, (areaSqM * perHundredSqM / 100).ceil());
  }

  static double _estimateGlueKg(int area, bool isCeiling) {
    if (isCeiling) {
      return 0;
    }
    final areaSqM = area / (metricUnitsPerMm * metricUnitsPerMm) / 1000000;
    return areaSqM * 3.5 / 100;
  }

  static double _estimatePlasterKg(int area, PlasterSheetDirection direction) {
    final areaSqM = area / (metricUnitsPerMm * metricUnitsPerMm) / 1000000;
    final multiplier = direction == PlasterSheetDirection.vertical ? 1.2 : 1.0;
    return areaSqM * (24 + 8) * multiplier / 100;
  }

  static PlasterTakeoffSummary calculateTakeoff(
    List<PlasterRoomShape> roomShapes,
    List<PlasterSurfaceLayout> layouts,
    int wastePercent,
  ) {
    var insideCorners = 0;
    var outsideCorners = 0;
    var cornice = 0;
    var totalArea = 0;
    for (final shape in roomShapes) {
      final corners = _classifyCorners(shape);
      insideCorners += corners.$1 * shape.room.ceilingHeight;
      outsideCorners += corners.$2 * shape.room.ceilingHeight;
      if (shape.room.plasterCeiling) {
        cornice += shape.lines.fold<int>(0, (sum, line) => sum + line.length);
      }
    }
    final groupedPieces = <String, List<PlasterSheetPlacement>>{};
    final groupedSheetSizes = <String, (int, int)>{};
    var rawPurchasedArea = 0;
    var totalSheetCount = 0;
    var reusableOffcutArea = 0;
    for (final layout in layouts) {
      final roomUnitSystem = _unitSystemForArea(layout, roomShapes);
      final key =
          '${layout.material.id}:${layout.material.unitSystem.name}:'
          '${layout.material.width}:${layout.material.height}';
      final pieces = groupedPieces.putIfAbsent(key, () => []);
      for (final piece in layout.placements) {
        pieces.add(
          PlasterSheetPlacement(
            x: 0,
            y: 0,
            width: convertLength(
              piece.width,
              roomUnitSystem,
              layout.material.unitSystem,
            ),
            height: convertLength(
              piece.height,
              roomUnitSystem,
              layout.material.unitSystem,
            ),
          ),
        );
      }
      groupedSheetSizes.putIfAbsent(
        key,
        () => (layout.material.width, layout.material.height),
      );
    }
    for (final entry in groupedPieces.entries) {
      final sheetSize = groupedSheetSizes[entry.key]!;
      final packed = _packPieces(
        pieces: entry.value,
        sheetWidth: sheetSize.$1,
        sheetHeight: sheetSize.$2,
        minReusableEdge: minEdgePiece(_unitSystemForMaterialKey(entry.key)),
      );
      totalSheetCount += packed.sheetCount;
      rawPurchasedArea += packed.sheetCount * sheetSize.$1 * sheetSize.$2;
      reusableOffcutArea += packed.reusableArea;
    }
    totalArea = layouts.fold<int>(0, (sum, layout) => sum + layout.area);
    final orderedSheetCount = max(
      totalSheetCount,
      (totalSheetCount * (100 + wastePercent) / 100).ceil(),
    );
    final contingencySheetCount = orderedSheetCount - totalSheetCount;
    final averageSheetArea = totalSheetCount == 0
        ? 0.0
        : rawPurchasedArea / totalSheetCount;
    final cutWasteArea = max(0, rawPurchasedArea - totalArea);
    final contingencyWasteArea = max(
      0,
      (averageSheetArea * contingencySheetCount).round(),
    );
    final estimatedWasteArea = cutWasteArea;
    final estimatedWastePercent = totalArea == 0
        ? 0.0
        : (estimatedWasteArea / totalArea) * 100;
    return PlasterTakeoffSummary(
      totalSheetCount: totalSheetCount,
      totalSheetCountWithWaste: orderedSheetCount,
      surfaceArea: totalArea,
      purchasedBoardArea: rawPurchasedArea,
      cutWasteArea: cutWasteArea,
      contingencyWasteArea: contingencyWasteArea,
      reusableOffcutArea: reusableOffcutArea,
      estimatedWasteArea: estimatedWasteArea,
      estimatedWastePercent: estimatedWastePercent,
      contingencySheetCount: contingencySheetCount,
      corniceLength: cornice,
      insideCornerLength: insideCorners,
      outsideCornerLength: outsideCorners,
      tapeLength: layouts.fold<int>(
        insideCorners,
        (sum, layout) => sum + layout.estimatedJointTapeLength,
      ),
      screwCount: layouts.fold<int>(
        0,
        (sum, layout) => sum + layout.estimatedScrewCount,
      ),
      glueKg: layouts.fold<double>(
        0,
        (sum, layout) => sum + layout.estimatedGlueKg,
      ),
      plasterKg: layouts.fold<double>(
        0,
        (sum, layout) => sum + layout.estimatedPlasterKg,
      ),
      corniceCementKg: cornice / metricUnitsPerMm / 1000 * 0.12,
    );
  }

  static PreferredUnitSystem _unitSystemForArea(
    PlasterSurfaceLayout layout,
    List<PlasterRoomShape> roomShapes,
  ) => roomShapes
      .firstWhere((shape) => shape.room.id == layout.roomId)
      .room
      .unitSystem;

  static List<PlasterProjectSheet> buildProjectSheetExplorer(
    List<PlasterRoomShape> roomShapes,
    List<PlasterSurfaceLayout> layouts,
  ) {
    final groupedPieces = <String, List<_PackableSurfacePiece>>{};
    final groupedMaterials = <String, PlasterMaterialSize>{};
    final groupedSheetSizes = <String, (int, int)>{};

    for (final layout in layouts) {
      final roomUnitSystem = _unitSystemForArea(layout, roomShapes);
      final key =
          '${layout.material.id}:${layout.material.unitSystem.name}:'
          '${layout.material.width}:${layout.material.height}';
      final pieces = groupedPieces.putIfAbsent(key, () => []);
      for (final piece in layout.placements) {
        pieces.add(
          _PackableSurfacePiece(
            surfaceLabel: layout.label,
            width: convertLength(
              piece.width,
              roomUnitSystem,
              layout.material.unitSystem,
            ),
            height: convertLength(
              piece.height,
              roomUnitSystem,
              layout.material.unitSystem,
            ),
          ),
        );
      }
      groupedMaterials.putIfAbsent(key, () => layout.material);
      groupedSheetSizes.putIfAbsent(
        key,
        () => (layout.material.width, layout.material.height),
      );
    }

    var nextSheetNumber = 1;
    final orderedKeys = groupedPieces.keys.toList()
      ..sort((left, right) {
        final leftMaterial = groupedMaterials[left]!;
        final rightMaterial = groupedMaterials[right]!;
        final nameCompare = leftMaterial.name.compareTo(rightMaterial.name);
        if (nameCompare != 0) {
          return nameCompare;
        }
        return leftMaterial.id.compareTo(rightMaterial.id);
      });

    final sheets = <PlasterProjectSheet>[];
    for (final key in orderedKeys) {
      final material = groupedMaterials[key]!;
      final sheetSize = groupedSheetSizes[key]!;
      final groupStartSheetNumber = nextSheetNumber;
      final packedSheets = _packSurfacePiecesForExplorer(
        pieces: groupedPieces[key]!,
        sheetWidth: sheetSize.$1,
        sheetHeight: sheetSize.$2,
        minReusableEdge: minEdgePiece(_unitSystemForMaterialKey(key)),
      );
      for (final packedSheet in packedSheets) {
        sheets.add(
          PlasterProjectSheet(
            sheetNumber: nextSheetNumber++,
            material: material,
            sheetWidth: sheetSize.$1,
            sheetHeight: sheetSize.$2,
            usedPieces: [
              for (final piece in packedSheet.usedPieces)
                PlasterProjectSheetPiece(
                  x: piece.x,
                  y: piece.y,
                  width: piece.width,
                  height: piece.height,
                  surfaceLabel: piece.surfaceLabel,
                  reusedOffcut: piece.reusedOffcut,
                  sourceSheetIndex: piece.sourceSheetIndex,
                  sourceSheetNumber: piece.sourceSheetIndex == null
                      ? null
                      : groupStartSheetNumber + piece.sourceSheetIndex!,
                ),
            ],
            offcuts: [
              for (final rect in packedSheet.freeRects)
                PlasterSheetOffcut(
                  x: rect.x,
                  y: rect.y,
                  width: rect.width,
                  height: rect.height,
                  reusable:
                      rect.width >=
                          minEdgePiece(_unitSystemForMaterialKey(key)) &&
                      rect.height >=
                          minEdgePiece(_unitSystemForMaterialKey(key)),
                  reusedLater: rect.reusedLater,
                ),
            ],
          ),
        );
      }
    }
    return sheets;
  }

  static (int, int) _classifyCorners(PlasterRoomShape shape) {
    if (shape.lines.length < 3) {
      return (0, 0);
    }
    final areaSign = _signedArea(shape.lines);
    var inside = 0;
    var outside = 0;
    for (var i = 0; i < shape.lines.length; i++) {
      final previous =
          shape.lines[(i - 1 + shape.lines.length) % shape.lines.length];
      final current = shape.lines[i];
      final next = lineEnd(shape.lines, i);
      final ax = current.startX - previous.startX;
      final ay = current.startY - previous.startY;
      final bx = next.x - current.startX;
      final by = next.y - current.startY;
      final cross = ax * by - ay * bx;
      final isInside = areaSign >= 0 ? cross >= 0 : cross <= 0;
      if (isInside) {
        inside++;
      } else {
        outside++;
      }
    }
    return (inside, outside);
  }

  static int _signedArea(List<PlasterRoomLine> lines) {
    var area = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final end = lineEnd(lines, i);
      area += line.startX * end.y - end.x * line.startY;
    }
    return area;
  }

  static String _surfaceLabel({
    required String name,
    required int width,
    required int height,
    required PreferredUnitSystem unitSystem,
  }) =>
      '$name (w: ${formatDisplayLength(width, unitSystem)} x '
      'h: ${formatDisplayLength(height, unitSystem)})';

  static (int, int, int, int) _bounds(List<PlasterRoomLine> lines) {
    final xs = lines.map((line) => line.startX).toList()..sort();
    final ys = lines.map((line) => line.startY).toList()..sort();
    return (xs.first, ys.first, xs.last, ys.last);
  }
}
