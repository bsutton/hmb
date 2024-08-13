import '../../dao/dao_system.dart';

enum DimensionType {
  length('mm', 'in'),
  area('m²', ''),
  volume('m³', 'ft²'),
  weight('kg', 'lb');

  const DimensionType(this.defaultUnitMetric, this.defaultUnitImperial);

  final String defaultUnitMetric;
  final String defaultUnitImperial;

  static DimensionType valueOf(String name) {
    try {
      return values.byName(name);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      return DimensionType.length;
    }
  }
}

enum PreferredUnitSystem { metric, imperial }

/// Gets the list of valid units (mm, cm, m) for the given [dimensionType]
/// using the user's preferred Unit System (metric or imperial)
Future<List<String>> getUnitsForDimension(DimensionType dimensionType) async {
  final system = await DaoSystem().get();

  return system!.preferredUnitSystem == PreferredUnitSystem.metric
      ? metricUnits[dimensionType]!
      : imperialUnits[dimensionType]!;
}

Future<String> getDefaultUnitForDimension(DimensionType dimensionType) async {
  final system = await DaoSystem().get();

  switch (system!.preferredUnitSystem) {
    case PreferredUnitSystem.imperial:
      return dimensionType.defaultUnitImperial;
    case PreferredUnitSystem.metric:
      return dimensionType.defaultUnitMetric;
  }
}

const Map<DimensionType, List<String>> metricUnits = {
  DimensionType.length: ['mm', 'cm', 'm'],
  DimensionType.area: ['m²', 'cm²'],
  DimensionType.volume: ['m³', 'liters'],
  DimensionType.weight: ['kg', 'g', 't'],
};

const Map<DimensionType, List<String>> imperialUnits = {
  DimensionType.length: ['in', 'ft', 'yd'],
  DimensionType.area: ['ft²', 'yd²'],
  DimensionType.volume: ['ft³', 'gallons'],
  DimensionType.weight: ['lb', 'oz', 'ton'],
};

extension DimensionTypeExtension on DimensionType {
  String get displayName {
    switch (this) {
      case DimensionType.length:
        return 'Length';
      case DimensionType.area:
        return 'Area';
      case DimensionType.volume:
        return 'Volume';
      case DimensionType.weight:
        return 'Weight';
    }
  }

  List<String> get labels {
    switch (this) {
      case DimensionType.length:
        return ['Length'];
      case DimensionType.area:
        return ['Length', 'Width'];
      case DimensionType.volume:
        return ['Height', 'Width', 'Depth'];
      case DimensionType.weight:
        return ['Weight'];
    }
  }
}
