enum ExplorerUnitSystem { metric, imperial }

enum ExplorerSheetDirection { auto, horizontal, vertical }

extension ExplorerSheetDirectionX on ExplorerSheetDirection {
  String get layoutLabel => switch (this) {
    ExplorerSheetDirection.auto => 'Auto',
    ExplorerSheetDirection.horizontal => 'Horizontal lay',
    ExplorerSheetDirection.vertical => 'Vertical lay',
  };
}

const _metricUnitsPerMm = 10;
const _imperialUnitsPerInch = 1000;
const _inchesPerFoot = 12;

String formatExplorerDisplayArea(int area, ExplorerUnitSystem unitSystem) {
  if (unitSystem == ExplorerUnitSystem.metric) {
    final squareMeters = area / 100000000;
    return '${squareMeters.toStringAsFixed(2)} m²';
  }
  final squareFeet =
      area / (_imperialUnitsPerInch * _imperialUnitsPerInch) / 144;
  return '${squareFeet.toStringAsFixed(2)} ft²';
}

String formatExplorerDisplayLength(int value, ExplorerUnitSystem unitSystem) {
  if (unitSystem == ExplorerUnitSystem.metric) {
    return '${(value / _metricUnitsPerMm).round()} mm';
  }

  final totalInches = value / _imperialUnitsPerInch;
  final feet = totalInches ~/ _inchesPerFoot;
  final remainingInches = totalInches - feet * _inchesPerFoot;
  final wholeInches = remainingInches.floor();
  final fractionalInches = remainingInches - wholeInches;
  final sixteenths = (fractionalInches * 16).round();

  if (sixteenths == 0) {
    return "$feet' $wholeInches\"";
  }
  if (sixteenths == 16) {
    return "$feet' ${wholeInches + 1}\"";
  }
  return "$feet' $wholeInches $sixteenths/16\"";
}
