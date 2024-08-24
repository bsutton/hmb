import 'package:fixed/fixed.dart';

abstract class Units {
  const Units(this.name, {this.labels = const []});

  final String name;
  final List<String> labels;

  static Units? fromName(String unitName) => _unitsMap[unitName];

  static Units defaultUnits = mm;

  @override
  String toString() => name;

  int get dimensions;

  String format(List<Fixed> values);

  String calc(List<String> values) {
    final fixes = <Fixed>[];

    for (final value in values) {
      fixes.add(Fixed.tryParse(value) ?? Fixed.zero);
    }
    return _calc(fixes).toString();
  }

  Fixed _calc(List<Fixed> values);

  String get measure;
}

class Units1D extends Units {
  const Units1D(super.name, {super.labels = const []});

  @override
  String get measure => name;

  @override
  int get dimensions => 1;

  @override
  String format(List<Fixed> values) => '${labels[0]}: ${values[0]} $measure';

  @override
  Fixed _calc(List<Fixed> values) =>
      values.isEmpty ? Fixed.zero : linearCalc(values[0]);
}

class Units2D extends Units {
  const Units2D(super.name, {required this.measure, super.labels = const []});

  /// The unit in which this unit is measured. e.g. mm
  @override
  final String measure;

  @override
  int get dimensions => 2;

  @override
  String format(List<Fixed> values) =>
      '''${labels[0]}: ${values[0]} $measure, ${labels[1]}: ${values[1]} $measure Total: ${_calc(values)} $name''';

  @override
  Fixed _calc(List<Fixed> values) =>
      values.length < 2 ? Fixed.zero : areaCalc(values[0], values[1]);
}

class Units3D extends Units {
  const Units3D(super.name, {required this.measure, super.labels = const []});

  /// The unit in which this unit is measured. e.g mm.
  @override
  final String measure;

  @override
  int get dimensions => 3;

  @override
  String format(List<Fixed> values) =>
      '''${labels[0]}: ${values[0]} $measure, ${labels[1]}: ${values[1]} $measure, ${labels[2]}: ${values[2]} $measure Total: ${_calc(values)} $name''';

  @override
  Fixed _calc(List<Fixed> values) => values.length < 3
      ? Fixed.zero
      : volumeCalc(values[0], values[1], values[2]);
}

// Calculation functions
Fixed linearCalc(Fixed value) => value; // 1D calculation
Fixed areaCalc(Fixed d1, Fixed d2) =>
    Fixed.copyWith(d1 * d2, scale: 3); // 2D calculation
Fixed volumeCalc(Fixed d1, Fixed d2, Fixed d3) =>
    Fixed.copyWith(d1 * d2 * d3, scale: 3); // 3D calculation

// Define named variables for each unit with labels

/// linear units
const Units mm = Units1D('mm', labels: ['Length']);
const Units cm = Units1D('cm', labels: ['Length']);
const Units m = Units1D('m', labels: ['Length']);
const Units yd = Units1D('yd', labels: ['Length']);
const Units ft = Units1D('ft', labels: ['Length']);
const Units inch = Units1D('in', labels: ['Length']);

/// area units
const Units m2 = Units2D('m²', measure: 'm', labels: ['Length', 'Width']);
const Units cm2 = Units2D('cm²', measure: 'cm', labels: ['Length', 'Width']);
const Units yd2 = Units2D('yd²', measure: 'yd', labels: ['Length', 'Width']);
const Units ft2 = Units2D('ft²', measure: 'ft', labels: ['Length', 'Width']);

/// Volume units
const Units m3 =
    Units3D('m³', measure: 'm', labels: ['Height', 'Width', 'Depth']);
const Units liters = Units1D('litres', labels: ['Volume']);
const Units ft3 =
    Units3D('ft³', measure: 'ft³', labels: ['Height', 'Width', 'Depth']);
const Units gallons = Units1D('gallons', labels: ['Volume']);

/// Weight
const Units t = Units1D('t', labels: ['Weight']);
const Units kg = Units1D('kg', labels: ['Weight']);
const Units g = Units1D('g', labels: ['Weight']);
const Units ton = Units1D('ton', labels: ['Weight']);
const Units lb = Units1D('lb', labels: ['Weight']);
const Units oz = Units1D('oz', labels: ['Weight']);

// Map of unit names to Units objects
Map<String, Units> _unitsMap = {
  'mm': mm,
  'cm': cm,
  'm': m,
  'yd': yd,
  'ft': ft,
  'in': inch,
  'm²': m2,
  'cm²': cm2,
  'yd²': yd2,
  'ft²': ft2,
  'm³': m3,
  'liters': liters,
  'ft³': ft3,
  'gallons': gallons,
  't': t,
  'kg': kg,
  'g': g,
  'ton': ton,
  'lb': lb,
  'oz': oz,
};
