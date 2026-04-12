import 'dart:math';

import 'room_canvas_models.dart';
import '../room_editor.dart';

class RoomCanvasGeometry {
  static const metricUnitsPerMm = 10;
  static const imperialUnitsPerInch = 1000;
  static const inchesPerFoot = 12;
  static const metricGrid = 1000;
  static const imperialGrid = 6000;

  static RoomEditorIntPoint lineEnd(List<RoomEditorLine> lines, int index) {
    final next = lines[(index + 1) % lines.length];
    return RoomEditorIntPoint(next.startX, next.startY);
  }

  static int derivedLength(List<RoomEditorLine> lines, int index) {
    final line = lines[index];
    final end = lineEnd(lines, index);
    final dx = end.x - line.startX;
    final dy = end.y - line.startY;
    return sqrt(dx * dx + dy * dy).round();
  }

  static List<RoomEditorLine> normalizeSeq(List<RoomEditorLine> lines) => [
    for (var i = 0; i < lines.length; i++)
      lines[i].copyWith(seqNo: i, length: derivedLength(lines, i)),
  ];

  static int defaultGridSize(RoomEditorUnitSystem unitSystem) =>
      unitSystem == RoomEditorUnitSystem.metric ? metricGrid : imperialGrid;

  static RoomEditorIntPoint snapPoint(
    RoomEditorIntPoint point,
    RoomEditorUnitSystem unitSystem,
  ) {
    final grid = defaultGridSize(unitSystem);
    return RoomEditorIntPoint(
      ((point.x / grid).round()) * grid,
      ((point.y / grid).round()) * grid,
    );
  }

  static String formatDisplayLength(
    int value,
    RoomEditorUnitSystem unitSystem,
  ) {
    if (unitSystem == RoomEditorUnitSystem.metric) {
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

  static String unitLabel(RoomEditorUnitSystem unitSystem) =>
      unitSystem == RoomEditorUnitSystem.metric ? 'mm' : 'ft/in';

  static int? parseDisplayLength(String raw, RoomEditorUnitSystem unitSystem) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (unitSystem == RoomEditorUnitSystem.metric) {
      final parsed = double.tryParse(trimmed);
      if (parsed == null) {
        return null;
      }
      return (parsed * metricUnitsPerMm).round();
    }

    final feetInches = RegExp(
      r"""^\s*(\d+)\s*'\s*(?:(\d+(?:\.\d+)?)\s*(?:")?)?\s*$""",
    ).firstMatch(trimmed);
    if (feetInches != null) {
      final feet = int.tryParse(feetInches.group(1) ?? '0') ?? 0;
      final inches = double.tryParse(feetInches.group(2) ?? '0') ?? 0;
      return ((feet * inchesPerFoot + inches) * imperialUnitsPerInch).round();
    }

    final plain = double.tryParse(trimmed);
    if (plain != null) {
      return (plain * imperialUnitsPerInch).round();
    }

    return null;
  }

  static String _formatFeetAndInches(int feet, int inches, int sixteenths) {
    final normalizedFeet = feet + inches ~/ inchesPerFoot;
    final normalizedInches = inches % inchesPerFoot;
    if (sixteenths <= 0) {
      return "$normalizedFeet' $normalizedInches\"";
    }
    return "$normalizedFeet' $normalizedInches $sixteenths/16\"";
  }
}
