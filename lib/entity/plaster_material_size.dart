/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import '../util/dart/measurement_type.dart';
import 'entity.dart';

class PlasterMaterialSize extends Entity<PlasterMaterialSize> {
  final int projectId;
  final String name;
  final PreferredUnitSystem unitSystem;
  final int width;
  final int height;

  PlasterMaterialSize._({
    required super.id,
    required this.projectId,
    required this.name,
    required this.unitSystem,
    required this.width,
    required this.height,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterMaterialSize.forInsert({
    required this.projectId,
    required this.name,
    required this.unitSystem,
    required this.width,
    required this.height,
  }) : super.forInsert();

  PlasterMaterialSize copyWith({
    int? projectId,
    String? name,
    PreferredUnitSystem? unitSystem,
    int? width,
    int? height,
  }) => PlasterMaterialSize._(
    id: id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    unitSystem: unitSystem ?? this.unitSystem,
    width: width ?? this.width,
    height: height ?? this.height,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterMaterialSize.fromMap(Map<String, dynamic> map) =>
      PlasterMaterialSize._(
        id: map['id'] as int,
        projectId: map['project_id'] as int,
        name: map['name'] as String? ?? '',
        unitSystem: (map['unit_system'] as String?) == 'imperial'
            ? PreferredUnitSystem.imperial
            : PreferredUnitSystem.metric,
        width: map['width'] as int? ?? 0,
        height: map['height'] as int? ?? 0,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'name': name,
    'unit_system': unitSystem.name,
    'width': width,
    'height': height,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
