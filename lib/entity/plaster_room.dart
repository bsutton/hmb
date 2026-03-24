/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import '../util/dart/measurement_type.dart';
import 'entity.dart';

class PlasterRoom extends Entity<PlasterRoom> {
  final int projectId;
  final String name;
  final PreferredUnitSystem unitSystem;
  final int ceilingHeight;
  final bool plasterCeiling;

  PlasterRoom._({
    required super.id,
    required this.projectId,
    required this.name,
    required this.unitSystem,
    required this.ceilingHeight,
    required this.plasterCeiling,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterRoom.forInsert({
    required this.projectId,
    required this.name,
    required this.unitSystem,
    required this.ceilingHeight,
    this.plasterCeiling = true,
  }) : super.forInsert();

  PlasterRoom copyWith({
    int? projectId,
    String? name,
    PreferredUnitSystem? unitSystem,
    int? ceilingHeight,
    bool? plasterCeiling,
  }) => PlasterRoom._(
    id: id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    unitSystem: unitSystem ?? this.unitSystem,
    ceilingHeight: ceilingHeight ?? this.ceilingHeight,
    plasterCeiling: plasterCeiling ?? this.plasterCeiling,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterRoom.fromMap(Map<String, dynamic> map) => PlasterRoom._(
    id: map['id'] as int,
    projectId: map['project_id'] as int,
    name: map['name'] as String? ?? '',
    unitSystem: (map['unit_system'] as String?) == 'imperial'
        ? PreferredUnitSystem.imperial
        : PreferredUnitSystem.metric,
    ceilingHeight: map['ceiling_height'] as int? ?? 24000,
    plasterCeiling: (map['plaster_ceiling'] as int? ?? 1) == 1,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'name': name,
    'unit_system': unitSystem.name,
    'ceiling_height': ceilingHeight,
    'plaster_ceiling': plasterCeiling ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
