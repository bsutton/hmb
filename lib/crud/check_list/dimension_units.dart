import 'dimension_type.dart';


enum PreferredUnits {
  metric,
  imperial
} 

const Map<DimensionType, List<String>> metricUnits = {
  DimensionType.length: ['mm', 'cm', 'm'],
  DimensionType.area: ['m²', 'cm²'],
  DimensionType.volume: ['m³', 'liters'],
  DimensionType.weight: ['kg', 'g'],
};

const Map<DimensionType, List<String>> imperialUnits = {
  DimensionType.length: ['in', 'ft', 'yd'],
  DimensionType.area: ['ft²', 'yd²'],
  DimensionType.volume: ['ft³', 'gallons'],
  DimensionType.weight: ['lb', 'oz'],
};
