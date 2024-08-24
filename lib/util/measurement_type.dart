import '../dao/dao_system.dart';
import 'units.dart';

Map<String, MeasurementType> _measurementTypes = {
  length.name: length,
  area.name: area,
  volume.name: volume,
  weight.name: weight,
};

class MeasurementType {
  /// Defines a type of measurement such
  /// as length, weight, volume and includes
  /// both the imperial and metric units for that
  /// type of measurement.
  ///
  /// The [name] of the MeasurementType such as 'volume'.
  /// The [defaultMetric] Units used by the metric system.
  /// The [defaultImperial] Units used by the imperial system.
  /// The list of [metric] units for this measurement type.
  /// The list of [imperial] units for this measurement type.
  const MeasurementType(
      {required this.name,
      required this.defaultMetric,
      required this.defaultImperial,
      required this.metric,
      required this.imperial});

  final String name;
  final Units defaultMetric;
  final Units defaultImperial;

  final List<Units> metric;
  final List<Units> imperial;

  static MeasurementType get defaultMeasurementType => length;

  static MeasurementType? fromName(String name) => _measurementTypes[name];

  static List<MeasurementType> get list => _measurementTypes.values.toList();

  @override
  String toString() => name;
}

// Use the defined variables in the MeasurementType constructors
const length = MeasurementType(
    name: 'length',
    defaultMetric: mm,
    defaultImperial: inch,
    metric: [
      m,
      cm,
      mm
    ],
    imperial: [
      yd,
      ft,
      inch,
    ]);

const area = MeasurementType(
    name: 'area',
    defaultMetric: m2,
    defaultImperial: yd2,
    metric: [
      m2,
      cm2,
    ],
    imperial: [
      yd2,
      ft2,
    ]);

const volume = MeasurementType(
    name: 'volume',
    defaultMetric: m3,
    defaultImperial: ft3,
    metric: [
      m3,
      liters,
    ],
    imperial: [
      ft3,
      gallons,
    ]);

const weight = MeasurementType(
    name: 'weight',
    defaultMetric: kg,
    defaultImperial: lb,
    metric: [
      t,
      kg,
      g,
    ],
    imperial: [
      ton,
      lb,
      oz,
    ]);
    
enum PreferredUnitSystem { metric, imperial }

/// Gets the list of valid units (mm, cm, m) for the given [measurementType]
/// using the user's preferred Unit System (metric or imperial)
Future<List<Units>> getUnitsForMeasurementType(
    MeasurementType measurementType) async {
  final system = await DaoSystem().get();

  return system!.preferredUnitSystem == PreferredUnitSystem.metric
      ? measurementType.metric
      : measurementType.imperial;
}

Future<Units> getDefaultUnitForMeasurementType(
    MeasurementType measurementType) async {
  final system = await DaoSystem().get();

  switch (system!.preferredUnitSystem) {
    case PreferredUnitSystem.imperial:
      return measurementType.defaultImperial;
    case PreferredUnitSystem.metric:
      return measurementType.defaultMetric;
  }
}
