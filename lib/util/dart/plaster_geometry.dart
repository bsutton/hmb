/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:math';

import '../../entity/plaster_material_size.dart';
import '../../entity/plaster_room.dart';
import '../../entity/plaster_room_line.dart';
import '../../entity/plaster_room_opening.dart';
import 'measurement_type.dart';
import 'plaster_sheet_direction.dart';

class IntPoint {
  final int x;
  final int y;

  const IntPoint(this.x, this.y);
}

class PlasterRoomShape {
  final PlasterRoom room;
  final List<PlasterRoomLine> lines;
  final List<PlasterRoomOpening> openings;

  const PlasterRoomShape({
    required this.room,
    required this.lines,
    required this.openings,
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
    required this.estimatedJointTapeLength,
    required this.estimatedScrewCount,
    required this.estimatedGlueKg,
    required this.estimatedPlasterKg,
  });
}

class PlasterTakeoffSummary {
  final int totalSheetCount;
  final int totalSheetCountWithWaste;
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

class _FreeRect {
  final int x;
  final int y;
  final int width;
  final int height;

  const _FreeRect(this.x, this.y, this.width, this.height);

  bool isContainedIn(_FreeRect other) =>
      x >= other.x &&
      y >= other.y &&
      x + width <= other.x + other.width &&
      y + height <= other.y + other.height;
}

class _ProjectLayoutScore {
  final int sheetCount;
  final int wasteArea;

  const _ProjectLayoutScore({
    required this.sheetCount,
    required this.wasteArea,
  });
}

class _ProjectLayoutState {
  final List<PlasterSurfaceLayout> layouts;
  final _ProjectLayoutScore score;

  const _ProjectLayoutState({
    required this.layouts,
    required this.score,
  });
}

class PlasterGeometry {
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

  static List<PlasterSurfaceLayout> calculateLayout(
    List<PlasterRoomShape> roomShapes,
    List<PlasterMaterialSize> materials,
  ) {
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
    return _optimizeProjectLayouts(candidateGroups, roomShapes);
  }

  static List<PlasterSurfaceLayout> _surfaceCandidates({
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
      for (final candidate in _directionCandidates(
        direction: direction,
        sheetWidth: sheetWidth,
        sheetHeight: sheetHeight,
      )) {
        final plan = _buildPlacements(
          width: width,
          height: height,
          sheetWidth: candidate.$2,
          sheetHeight: candidate.$3,
          minEdge: minEdgePiece(room.unitSystem),
          staggerHorizontalStarter:
              !isCeiling &&
              candidate.$1 == PlasterSheetDirection.horizontal,
        );
        if (plan == null) {
          continue;
        }
        final count = _countSheetsForPieces(
          pieces: plan.$1,
          sheetWidth: candidate.$2,
          sheetHeight: candidate.$3,
        );
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
          sheetCount: count,
          sheetCountWithWaste: count,
          placements: plan.$1,
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
      }
    }
    candidates.sort((left, right) {
      final leftCoverage = _layoutCoverage(left, room.unitSystem);
      final rightCoverage = _layoutCoverage(right, room.unitSystem);
      final sheetCountCompare = left.sheetCount.compareTo(right.sheetCount);
      if (sheetCountCompare != 0) {
        return sheetCountCompare;
      }
      return leftCoverage.compareTo(rightCoverage);
    });
    return candidates;
  }

  static List<PlasterSurfaceLayout> _optimizeProjectLayouts(
    List<List<PlasterSurfaceLayout>> candidateGroups,
    List<PlasterRoomShape> roomShapes,
  ) {
    if (candidateGroups.isEmpty) {
      return const [];
    }
    const beamWidth = 24;
    var beam = <_ProjectLayoutState>[
      const _ProjectLayoutState(
        layouts: [],
        score: _ProjectLayoutScore(sheetCount: 0, wasteArea: 0),
      ),
    ];

    for (final group in candidateGroups) {
      final nextBeam = <_ProjectLayoutState>[];
      for (final state in beam) {
        for (final candidate in group) {
          final layouts = [...state.layouts, candidate];
          nextBeam.add(
            _ProjectLayoutState(
              layouts: layouts,
              score: _evaluateProjectLayouts(layouts, roomShapes),
            ),
          );
        }
      }
      nextBeam.sort((left, right) {
        if (_isBetterProjectScore(left.score, right.score)) {
          return -1;
        }
        if (_isBetterProjectScore(right.score, left.score)) {
          return 1;
        }
        return 0;
      });
      beam = nextBeam.take(beamWidth).toList();
    }
    return beam.first.layouts;
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
    List<PlasterRoomShape> roomShapes,
  ) {
    final groupedPieces = <String, List<PlasterSheetPlacement>>{};
    final groupedSheetSizes = <String, (int, int)>{};
    var sheetCount = 0;
    var wasteArea = 0;

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
      final count = _countSheetsForPieces(
        pieces: entry.value,
        sheetWidth: sheetSize.$1,
        sheetHeight: sheetSize.$2,
      );
      final sheetArea = sheetSize.$1 * sheetSize.$2;
      final pieceArea = entry.value.fold<int>(
        0,
        (sum, piece) => sum + piece.width * piece.height,
      );
      sheetCount += count;
      wasteArea += max(0, count * sheetArea - pieceArea);
    }

    return _ProjectLayoutScore(sheetCount: sheetCount, wasteArea: wasteArea);
  }

  static bool _isBetterProjectScore(
    _ProjectLayoutScore left,
    _ProjectLayoutScore right,
  ) {
    if (left.sheetCount != right.sheetCount) {
      return left.sheetCount < right.sheetCount;
    }
    return left.wasteArea < right.wasteArea;
  }

  static List<(PlasterSheetDirection, int, int)> _directionCandidates({
    required PlasterSheetDirection direction,
    required int sheetWidth,
    required int sheetHeight,
  }) {
    final shortSide = min(sheetWidth, sheetHeight);
    final longSide = max(sheetWidth, sheetHeight);
    final horizontal = (PlasterSheetDirection.horizontal, longSide, shortSide);
    final vertical = (PlasterSheetDirection.vertical, shortSide, longSide);
    return switch (direction) {
      PlasterSheetDirection.horizontal => [horizontal],
      PlasterSheetDirection.vertical => [vertical],
      PlasterSheetDirection.auto => [horizontal, vertical],
    };
  }

  static (
    List<PlasterSheetPlacement>,
    int,
    int
  )? _buildPlacements({
    required int width,
    required int height,
    required int sheetWidth,
    required int sheetHeight,
    required int minEdge,
    required bool staggerHorizontalStarter,
  }) {
    final rowHeights = _axisPieces(height, sheetHeight, minEdge);
    if (rowHeights == null) {
      return null;
    }
    final placements = <PlasterSheetPlacement>[];
    var maxAcross = 0;
    var y = 0;
    for (var row = 0; row < rowHeights.length; row++) {
      final rowWidths =
          staggerHorizontalStarter && row.isEven
          ? _starterAxisPieces(width, sheetWidth, minEdge)
          : _axisPieces(width, sheetWidth, minEdge);
      if (rowWidths == null) {
        return null;
      }
      maxAcross = max(maxAcross, rowWidths.length);
      var x = 0;
      for (final pieceWidth in rowWidths) {
        placements.add(
          PlasterSheetPlacement(
            x: x,
            y: y,
            width: pieceWidth,
            height: rowHeights[row],
          ),
        );
        x += pieceWidth;
      }
      y += rowHeights[row];
    }
    return (
      placements,
      maxAcross,
      rowHeights.length,
    );
  }

  static List<int>? _starterAxisPieces(
    int surfaceLength,
    int sheetLength,
    int minEdge,
  ) {
    final starter = sheetLength ~/ 2;
    if (starter < minEdge || surfaceLength < starter) {
      return null;
    }
    if (surfaceLength == starter) {
      return [starter];
    }
    final trailing = _axisPieces(surfaceLength - starter, sheetLength, minEdge);
    if (trailing == null) {
      return null;
    }
    return [starter, ...trailing];
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
    final fullCount = surfaceLength ~/ sheetLength;
    final remainder = surfaceLength % sheetLength;
    if (remainder == 0) {
      return List<int>.filled(fullCount, sheetLength);
    }
    if (remainder >= minEdge) {
      return [...List<int>.filled(fullCount, sheetLength), remainder];
    }
    if (fullCount == 0) {
      return null;
    }
    final delta = minEdge - remainder;
    final firstPiece = sheetLength - delta;
    if (firstPiece < minEdge) {
      return null;
    }
    return [
      firstPiece,
      ...List<int>.filled(max(0, fullCount - 1), sheetLength),
      minEdge,
    ];
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

  static int _countSheetsForPieces({
    required List<PlasterSheetPlacement> pieces,
    required int sheetWidth,
    required int sheetHeight,
  }) {
    if (pieces.isEmpty) {
      return 0;
    }

    final sorted = [...pieces]..sort((left, right) {
      final heightCompare = right.height.compareTo(left.height);
      if (heightCompare != 0) {
        return heightCompare;
      }
      final widthCompare = right.width.compareTo(left.width);
      if (widthCompare != 0) {
        return widthCompare;
      }
      return (right.width * right.height).compareTo(left.width * left.height);
    });

    final sheets = <List<_FreeRect>>[];
    for (final piece in sorted) {
      var placed = false;
      for (final freeRects in sheets) {
        if (_placePieceInSheet(
          freeRects: freeRects,
          pieceWidth: piece.width,
          pieceHeight: piece.height,
        )) {
          placed = true;
          break;
        }
      }
      if (placed) {
        continue;
      }

      final freeRects = [const _FreeRect(0, 0, 0, 0)];
      freeRects[0] = _FreeRect(0, 0, sheetWidth, sheetHeight);
      final inserted = _placePieceInSheet(
        freeRects: freeRects,
        pieceWidth: piece.width,
        pieceHeight: piece.height,
      );
      if (!inserted) {
        return max(1, pieces.length);
      }
      sheets.add(freeRects);
    }

    return sheets.length;
  }

  static bool _placePieceInSheet({
    required List<_FreeRect> freeRects,
    required int pieceWidth,
    required int pieceHeight,
  }) {
    for (var i = 0; i < freeRects.length; i++) {
      final rect = freeRects[i];
      if (pieceWidth > rect.width || pieceHeight > rect.height) {
        continue;
      }
      freeRects.removeAt(i);
      final rightWidth = rect.width - pieceWidth;
      final bottomHeight = rect.height - pieceHeight;
      if (rightWidth > 0) {
        freeRects.add(
          _FreeRect(
            rect.x + pieceWidth,
            rect.y,
            rightWidth,
            pieceHeight,
          ),
        );
      }
      if (bottomHeight > 0) {
        freeRects.add(
          _FreeRect(
            rect.x,
            rect.y + pieceHeight,
            rect.width,
            bottomHeight,
          ),
        );
      }
      if (rightWidth > 0 && bottomHeight > 0) {
        freeRects.add(
          _FreeRect(
            rect.x + pieceWidth,
            rect.y + pieceHeight,
            rightWidth,
            bottomHeight,
          ),
        );
      }
      _pruneFreeRects(freeRects);
      return true;
    }
    return false;
  }

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

  static double _estimatePlasterKg(
    int area,
    PlasterSheetDirection direction,
  ) {
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
      final sheetCount = _countSheetsForPieces(
        pieces: entry.value,
        sheetWidth: sheetSize.$1,
        sheetHeight: sheetSize.$2,
      );
      totalSheetCount += sheetCount;
      rawPurchasedArea += sheetCount * sheetSize.$1 * sheetSize.$2;
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
    final estimatedWasteArea = max(
      0,
      (rawPurchasedArea - totalArea) +
          (averageSheetArea * contingencySheetCount).round(),
    );
    final estimatedWastePercent = totalArea == 0
        ? 0.0
        : (estimatedWasteArea / totalArea) * 100;
    return PlasterTakeoffSummary(
      totalSheetCount: totalSheetCount,
      totalSheetCountWithWaste: orderedSheetCount,
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

  static (int, int) _classifyCorners(PlasterRoomShape shape) {
    if (shape.lines.length < 3) {
      return (0, 0);
    }
    final areaSign = _signedArea(shape.lines);
    var inside = 0;
    var outside = 0;
    for (var i = 0; i < shape.lines.length; i++) {
      final previous = shape.lines[
          (i - 1 + shape.lines.length) % shape.lines.length];
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
      '$name (${formatDisplayLength(width, unitSystem)} x '
      '${formatDisplayLength(height, unitSystem)})';

  static (int, int, int, int) _bounds(List<PlasterRoomLine> lines) {
    final xs = lines.map((line) => line.startX).toList()..sort();
    final ys = lines.map((line) => line.startY).toList()..sort();
    return (xs.first, ys.first, xs.last, ys.last);
  }
}
