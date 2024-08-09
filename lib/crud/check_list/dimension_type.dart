enum DimensionType {
  length,
  area,
  volume,
  weight;

  static DimensionType valueOf(String name) {
    try {
      return values.byName(name);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      return DimensionType.length;
    }
  }
}

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
