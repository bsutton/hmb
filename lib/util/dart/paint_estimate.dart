import 'dart:math' as math;

import '../../entity/plaster_room.dart';
import '../../entity/plaster_room_line.dart';
import '../../entity/plaster_room_opening.dart';
import 'measurement_type.dart';
import 'plaster_geometry.dart';

enum PaintPreparation {
  dusting('Dusting', 0.01),
  washing('Sugar wash', 0.03),
  sanding('Sanding', 0.05),
  minorRepairs('Minor repairs', 0.10),
  mediumRepairs('Medium repairs', 0.20);

  const PaintPreparation(this.label, this.starterRate);
  final String label;
  final double starterRate;
}

enum PaintFinish {
  paint('Paint', 0.04),
  textured('Textured', 0.07);

  const PaintFinish(this.label, this.starterRate);
  final String label;
  final double starterRate;
}

/// Editable starter assumptions, not industry benchmarks. Preparation rates
/// cover the complete selected grade. No plasterboard settings are modified.
class PaintSettings {
  PaintPreparation preparation;
  PaintFinish finish;
  bool ceiling;
  bool complexWindows;
  int coats;
  int colours;
  double windowHours;
  double extraColourHours;
  final Set<int> excludedWalls;
  final Map<PaintPreparation, double> preparationRates;
  final Map<PaintFinish, double> finishRates;

  PaintSettings({
    this.preparation = PaintPreparation.dusting,
    this.finish = PaintFinish.paint,
    this.ceiling = true,
    this.complexWindows = false,
    this.coats = 2,
    this.colours = 1,
    this.windowHours = 0.5,
    this.extraColourHours = 0.25,
    Set<int>? excludedWalls,
    Map<PaintPreparation, double>? preparationRates,
    Map<PaintFinish, double>? finishRates,
  }) : excludedWalls = excludedWalls ?? {},
       preparationRates =
           preparationRates ??
           {
             for (final value in PaintPreparation.values)
               value: value.starterRate,
           },
       finishRates =
           finishRates ??
           {for (final value in PaintFinish.values) value: value.starterRate};

  factory PaintSettings.fromMap(Map<String, dynamic> map) {
    final result = PaintSettings(
      preparation: PaintPreparation.values.firstWhere(
        (value) => value.name == map['preparation'],
        orElse: () => PaintPreparation.dusting,
      ),
      finish: PaintFinish.values.firstWhere(
        (value) => value.name == map['finish'],
        orElse: () => PaintFinish.paint,
      ),
      ceiling: map['ceiling'] as bool? ?? true,
      complexWindows: map['complexWindows'] as bool? ?? false,
      coats: map['coats'] as int? ?? 2,
      colours: map['colours'] as int? ?? 1,
      windowHours: (map['windowHours'] as num?)?.toDouble() ?? 0.5,
      extraColourHours: (map['extraColourHours'] as num?)?.toDouble() ?? 0.25,
      excludedWalls: (map['excludedWalls'] as List<dynamic>? ?? [])
          .cast<int>()
          .toSet(),
    );
    final prep = map['preparationRates'] as Map<String, dynamic>? ?? {};
    final finish = map['finishRates'] as Map<String, dynamic>? ?? {};
    for (final value in PaintPreparation.values) {
      result.preparationRates[value] =
          (prep[value.name] as num?)?.toDouble() ?? value.starterRate;
    }
    for (final value in PaintFinish.values) {
      result.finishRates[value] =
          (finish[value.name] as num?)?.toDouble() ?? value.starterRate;
    }
    return result;
  }

  Map<String, dynamic> toMap() => {
    'preparation': preparation.name,
    'finish': finish.name,
    'ceiling': ceiling,
    'complexWindows': complexWindows,
    'coats': coats,
    'colours': colours,
    'windowHours': windowHours,
    'extraColourHours': extraColourHours,
    'excludedWalls': excludedWalls.toList(),
    'preparationRates': {
      for (final entry in preparationRates.entries) entry.key.name: entry.value,
    },
    'finishRates': {
      for (final entry in finishRates.entries) entry.key.name: entry.value,
    },
  };

  void validate() {
    if (coats < 1 ||
        colours < 1 ||
        [
          ...preparationRates.values,
          ...finishRates.values,
          windowHours,
          extraColourHours,
        ].any((rate) => !rate.isFinite || rate < 0)) {
      throw const FormatException(
        'Enter valid non-negative rates and positive counts.',
      );
    }
  }
}

class PaintEstimate {
  final double wallArea;
  final double ceilingArea;
  final int windows;
  final PaintSettings settings;

  PaintEstimate._(this.wallArea, this.ceilingArea, this.windows, this.settings);

  factory PaintEstimate.fromRoom(
    PlasterRoom room,
    List<PlasterRoomLine> lines,
    List<PlasterRoomOpening> openings,
    PaintSettings settings,
  ) {
    settings.validate();
    if (lines.length < 3 ||
        room.ceilingHeight <= 0 ||
        PlasterGeometry.polygonArea(lines) <= 0) {
      throw const FormatException(
        'Draw a valid closed room before estimating paint.',
      );
    }
    final metresPerUnit = room.unitSystem == PreferredUnitSystem.metric
        ? 0.0001
        : 0.0000254;
    var wallArea = 0.0;
    var windows = 0;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (settings.excludedWalls.contains(line.id)) {
        continue;
      }
      final end = PlasterGeometry.lineEnd(lines, index);
      final length = math.sqrt(
        math.pow(end.x - line.startX, 2) + math.pow(end.y - line.startY, 2),
      );
      final wallOpenings = openings.where((o) => o.lineId == line.id).toList();
      final removed = _openingUnionArea(
        wallOpenings,
        length,
        room.ceilingHeight.toDouble(),
      );
      wallArea +=
          (length * room.ceilingHeight - removed) *
          metresPerUnit *
          metresPerUnit;
      windows += wallOpenings
          .where((o) => o.type == PlasterOpeningType.window)
          .length;
    }
    return PaintEstimate._(
      wallArea,
      settings.ceiling
          ? PlasterGeometry.polygonArea(lines) * metresPerUnit * metresPerUnit
          : 0,
      windows,
      PaintSettings.fromMap(settings.toMap()),
    );
  }

  double get preparationHours =>
      (wallArea + ceilingArea) *
      settings.preparationRates[settings.preparation]!;
  double get paintingHours =>
      (wallArea + ceilingArea) *
      settings.coats *
      settings.finishRates[settings.finish]!;
  double get windowHours => windows * settings.windowHours;
  double get colourHours => (settings.colours - 1) * settings.extraColourHours;
  double get totalHours =>
      preparationHours + paintingHours + windowHours + colourHours;

  String get summary => [
    'Paint labour estimate',
    'Walls: ${wallArea.toStringAsFixed(2)} m² (openings deducted)',
    'Ceiling: ${ceilingArea.toStringAsFixed(2)} m²',
    'Preparation: ${settings.preparation.label}',
    'Preparation rate: ${settings.preparationRates[settings.preparation]} hours/m²',
    'Preparation effort: ${preparationHours.toStringAsFixed(2)} hours',
    'Finish: ${settings.finish.label}, ${settings.coats} coats',
    'Finish rate: ${settings.finishRates[settings.finish]} hours/m²/coat',
    'Painting effort: ${paintingHours.toStringAsFixed(2)} hours',
    'Windows: $windows; ${settings.complexWindows ? 'complex' : 'simple'}',
    'Window rate: ${settings.windowHours} hours/window (all coats)',
    'Window effort: ${windowHours.toStringAsFixed(2)} hours',
    'Colours: ${settings.colours}; ${settings.extraColourHours} hours/extra colour',
    'Colour setup effort: ${colourHours.toStringAsFixed(2)} hours',
    'Total labour: ${totalHours.toStringAsFixed(2)} hours',
    'Planning assumptions only. Check rates against your own experience.',
    'Excludes materials, drying time, travel, doors and other trim.',
  ].join('\n');
}

// Deduct the clipped union so overlapping openings are not counted twice.
double _openingUnionArea(
  List<PlasterRoomOpening> openings,
  double width,
  double height,
) {
  final rectangles = openings
      .map(
        (o) => (
          o.offsetFromStart.toDouble().clamp(0.0, width),
          (o.offsetFromStart + o.width).toDouble().clamp(0.0, width),
          o.sillHeight.toDouble().clamp(0.0, height),
          (o.sillHeight + o.height).toDouble().clamp(0.0, height),
        ),
      )
      .where((r) => r.$2 > r.$1 && r.$4 > r.$3)
      .toList();
  final edges = rectangles.expand((r) => [r.$1, r.$2]).toSet().toList()..sort();
  var area = 0.0;
  for (var i = 1; i < edges.length; i++) {
    final active =
        rectangles.where((r) => r.$1 < edges[i] && r.$2 > edges[i - 1]).toList()
          ..sort((a, b) => a.$3.compareTo(b.$3));
    var covered = 0.0;
    var top = 0.0;
    for (final rect in active) {
      covered += math.max(0, rect.$4 - math.max(top, rect.$3));
      top = math.max(top, rect.$4);
    }
    area += (edges[i] - edges[i - 1]) * covered;
  }
  return area;
}
