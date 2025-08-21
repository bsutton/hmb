/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import '../dao/dao_system.dart';
import 'units.dart';

Map<String, MeasurementType> _measurementTypes = {
  MeasurementType.length.name: MeasurementType.length,
  MeasurementType.area.name: MeasurementType.area,
  MeasurementType.volume.name: MeasurementType.volume,
  MeasurementType.weight.name: MeasurementType.weight,
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
  const MeasurementType({
    required this.name,
    required this.defaultMetric,
    required this.defaultImperial,
    required this.metric,
    required this.imperial,
  });

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

  // Use the defined variables in the MeasurementType constructors
  static const length = MeasurementType(
    name: 'length',
    defaultMetric: Units.mm,
    defaultImperial: Units.inch,
    metric: [Units.m, Units.cm, Units.mm],
    imperial: [Units.yd, Units.ft, Units.inch],
  );

  static const area = MeasurementType(
    name: 'area',
    defaultMetric: Units.m2,
    defaultImperial: Units.yd2,
    metric: [Units.m2, Units.cm2, Units.mm2],
    imperial: [Units.yd2, Units.ft2],
  );

  static const volume = MeasurementType(
    name: 'volume',
    defaultMetric: Units.m3,
    defaultImperial: Units.ft3,
    metric: [Units.m3, Units.liters],
    imperial: [Units.ft3, Units.gallons],
  );

  static const weight = MeasurementType(
    name: 'weight',
    defaultMetric: Units.kg,
    defaultImperial: Units.lb,
    metric: [Units.t, Units.kg, Units.g],
    imperial: [Units.ton, Units.lb, Units.oz],
  );
}

enum PreferredUnitSystem { metric, imperial }

/// Gets the list of valid units (mm, cm, m) for the given [measurementType]
/// using the user's preferred Unit System (metric or imperial)
Future<List<Units>> getUnitsForMeasurementType(
  MeasurementType measurementType,
) async {
  final system = await DaoSystem().get();

  return system.preferredUnitSystem == PreferredUnitSystem.metric
      ? measurementType.metric
      : measurementType.imperial;
}

Future<Units> getDefaultUnitForMeasurementType(
  MeasurementType measurementType,
) async {
  final system = await DaoSystem().get();

  switch (system.preferredUnitSystem) {
    case PreferredUnitSystem.imperial:
      return measurementType.defaultImperial;
    case PreferredUnitSystem.metric:
      return measurementType.defaultMetric;
  }
}
