/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import '../util/dart/measurement_type.dart';
import 'entity.dart';

class PlasterMaterialSize extends Entity<PlasterMaterialSize> {
  final int supplierId;
  final String name;
  final PreferredUnitSystem unitSystem;
  final int width;
  final int height;
  final int thickness;
  final bool excludedFromLayout;

  PlasterMaterialSize._({
    required super.id,
    required this.supplierId,
    required this.name,
    required this.unitSystem,
    required this.width,
    required this.height,
    required this.thickness,
    required this.excludedFromLayout,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterMaterialSize.forInsert({
    required this.supplierId,
    required this.name,
    required this.unitSystem,
    required this.width,
    required this.height,
    this.thickness = 100,
    this.excludedFromLayout = false,
  }) : super.forInsert();

  PlasterMaterialSize copyWith({
    int? supplierId,
    String? name,
    PreferredUnitSystem? unitSystem,
    int? width,
    int? height,
    int? thickness,
    bool? excludedFromLayout,
  }) => PlasterMaterialSize._(
    id: id,
    supplierId: supplierId ?? this.supplierId,
    name: name ?? this.name,
    unitSystem: unitSystem ?? this.unitSystem,
    width: width ?? this.width,
    height: height ?? this.height,
    thickness: thickness ?? this.thickness,
    excludedFromLayout: excludedFromLayout ?? this.excludedFromLayout,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterMaterialSize.fromMap(Map<String, dynamic> map) {
    final unitSystem = (map['unit_system'] as String?) == 'imperial'
        ? PreferredUnitSystem.imperial
        : PreferredUnitSystem.metric;
    return PlasterMaterialSize._(
      id: map['id'] as int,
      supplierId: map['supplier_id'] as int,
      name: map['name'] as String? ?? '',
      unitSystem: unitSystem,
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      thickness:
          map['thickness'] as int? ??
          (unitSystem == PreferredUnitSystem.metric ? 100 : 500),
      excludedFromLayout: (map['excluded_from_layout'] as int? ?? 0) == 1,
      createdDate: DateTime.parse(map['created_date'] as String),
      modifiedDate: DateTime.parse(map['modified_date'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'supplier_id': supplierId,
    'name': name,
    'unit_system': unitSystem.name,
    'width': width,
    'height': height,
    'thickness': thickness,
    'excluded_from_layout': excludedFromLayout ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
