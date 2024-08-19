class Units {
  const Units(this.name, this.dimensions);
  final String name;
  final int dimensions;

  static Units? fromName(String unitName) => _unitsMap[unitName];

  static Units defaultUnits = mm;

  @override
  String toString() => '$name dimensions: $dimensions';
}

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

// Define named variables for each unit
const Units mm = Units('mm', 1);
const Units cm = Units('cm', 1);
const Units m = Units('m', 1);
const Units yd = Units('yd', 1);
const Units ft = Units('ft', 1);
const Units inch = Units('in', 1);

const Units m2 = Units('m²', 2);
const Units cm2 = Units('cm²', 2);
const Units yd2 = Units('yd²', 2);
const Units ft2 = Units('ft²', 2);

const Units m3 = Units('m³', 3);
const Units liters = Units('liters', 1);
const Units ft3 = Units('ft³', 3);
const Units gallons = Units('gallons', 1);

const Units t = Units('t', 1);
const Units kg = Units('kg', 1);
const Units g = Units('g', 1);
const Units ton = Units('ton', 1);
const Units lb = Units('lb', 1);
const Units oz = Units('oz', 1);
