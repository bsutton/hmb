/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:math';

import '../../entity/plaster_material_size.dart';
import '../../entity/plaster_room.dart';
import '../../entity/plaster_room_line.dart';
import '../../entity/plaster_room_opening.dart';
import 'measurement_type.dart';

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

class PlasterSurfaceLayout {
  final String label;
  final PlasterMaterialSize material;
  final int area;
  final int sheetsAcross;
  final int sheetsDown;
  final int sheetCount;
  final int sheetCountWithWaste;

  const PlasterSurfaceLayout({
    required this.label,
    required this.material,
    required this.area,
    required this.sheetsAcross,
    required this.sheetsDown,
    required this.sheetCount,
    required this.sheetCountWithWaste,
  });
}

class PlasterLayoutResult {
  final List<PlasterSurfaceLayout> surfaces;

  const PlasterLayoutResult(this.surfaces);
}

class PlasterGeometry {
  static const metricUnitsPerMm = 10;
  static const imperialUnitsPerInch = 1000;
  static const metricGrid = 5000;
  static const imperialGrid = 6000;

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

  static List<PlasterRoomLine> insertAngle(
    List<PlasterRoomLine> lines,
    int lineIndex, {
    required bool leftTurn,
  }) {
    final line = lines[lineIndex];
    final end = lineEnd(lines, lineIndex);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    final currentLength = sqrt(dx * dx + dy * dy);
    if (currentLength < 3) {
      return lines;
    }
    final unitX = dx / currentLength;
    final unitY = dy / currentLength;
    final perpX = leftTurn ? -unitY : unitY;
    final perpY = leftTurn ? unitX : -unitX;
    final step = max(1, (currentLength / 3).round());
    final depth = max(1, (currentLength / 4).round());
    final p1 = IntPoint(
      line.startX + (unitX * step).round(),
      line.startY + (unitY * step).round(),
    );
    final p2 = IntPoint(
      p1.x + (perpX * depth).round(),
      p1.y + (perpY * depth).round(),
    );
    final p3 = IntPoint(
      line.startX + (unitX * step * 2).round() + (perpX * depth).round(),
      line.startY + (unitY * step * 2).round() + (perpY * depth).round(),
    );
    final updated = <PlasterRoomLine>[];
    for (var i = 0; i < lines.length; i++) {
      updated.add(lines[i]);
      if (i == lineIndex) {
        updated
          ..add(
            PlasterRoomLine.forInsert(
              roomId: line.roomId,
              seqNo: 0,
              startX: p1.x,
              startY: p1.y,
              length: step,
              plasterSelected: line.plasterSelected,
            ),
          )
          ..add(
            PlasterRoomLine.forInsert(
              roomId: line.roomId,
              seqNo: 0,
              startX: p2.x,
              startY: p2.y,
              length: step,
              plasterSelected: line.plasterSelected,
            ),
          )
          ..add(
            PlasterRoomLine.forInsert(
              roomId: line.roomId,
              seqNo: 0,
              startX: p3.x,
              startY: p3.y,
              length: step,
              plasterSelected: line.plasterSelected,
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
      unitSystem == PreferredUnitSystem.metric ? value / 10000 : value / 12000;

  static int fromDisplay(double value, PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric
      ? (value * 10000).round()
      : (value * 12000).round();

  static String unitLabel(PreferredUnitSystem unitSystem) =>
      unitSystem == PreferredUnitSystem.metric ? 'm' : 'ft';

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

  static List<PlasterSurfaceLayout> calculateLayout(
    List<PlasterRoomShape> roomShapes,
    List<PlasterMaterialSize> materials,
    int wastePercent,
  ) {
    final layouts = <PlasterSurfaceLayout>[];
    for (final shape in roomShapes) {
      if (shape.lines.isEmpty) {
        continue;
      }
      for (var i = 0; i < shape.lines.length; i++) {
        final line = shape.lines[i];
        if (!line.plasterSelected) {
          continue;
        }
        final layout = _bestMaterial(
          room: shape.room,
          width: line.length,
          height: shape.room.ceilingHeight,
          area: lineNetArea(shape.room, shape.lines, shape.openings, i),
          materials: materials,
          wastePercent: wastePercent,
          label: '${shape.room.name} wall ${i + 1}',
        );
        if (layout != null) {
          layouts.add(layout);
        }
      }
      if (shape.room.plasterCeiling) {
        final bounds = _bounds(shape.lines);
        final layout = _bestMaterial(
          room: shape.room,
          width: bounds.$3 - bounds.$1,
          height: bounds.$4 - bounds.$2,
          area: polygonArea(shape.lines),
          materials: materials,
          wastePercent: wastePercent,
          label: '${shape.room.name} ceiling',
        );
        if (layout != null) {
          layouts.add(layout);
        }
      }
    }
    return layouts;
  }

  static PlasterSurfaceLayout? _bestMaterial({
    required PlasterRoom room,
    required int width,
    required int height,
    required int area,
    required List<PlasterMaterialSize> materials,
    required int wastePercent,
    required String label,
  }) {
    PlasterSurfaceLayout? best;
    var bestCoverage = 0;
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
      for (final dims in [
        (sheetWidth, sheetHeight),
        (sheetHeight, sheetWidth),
      ]) {
        final across = max(1, (width / dims.$1).ceil());
        final down = max(1, (height / dims.$2).ceil());
        final count = across * down;
        final withWaste = max(1, (count * (100 + wastePercent) / 100).ceil());
        final coverage = dims.$1 * dims.$2 * count;
        final candidate = PlasterSurfaceLayout(
          label: label,
          material: material,
          area: area,
          sheetsAcross: across,
          sheetsDown: down,
          sheetCount: count,
          sheetCountWithWaste: withWaste,
        );
        if (best == null || coverage < bestCoverage) {
          best = candidate;
          bestCoverage = coverage;
        }
      }
    }
    return best;
  }

  static (int, int, int, int) _bounds(List<PlasterRoomLine> lines) {
    final xs = lines.map((line) => line.startX).toList()..sort();
    final ys = lines.map((line) => line.startY).toList()..sort();
    return (xs.first, ys.first, xs.last, ys.last);
  }
}
