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
import '../util/dart/plaster_sheet_direction.dart';
import 'entity.dart';

const _unsetPlasterRoomField = Object();

class PlasterRoom extends Entity<PlasterRoom> {
  final int projectId;
  final String name;
  final PreferredUnitSystem unitSystem;
  final int ceilingHeight;
  final bool plasterCeiling;
  final PlasterSheetDirection ceilingSheetDirection;
  final int? ceilingFramingSpacingOverride;
  final int? ceilingFramingOffsetOverride;
  final int? ceilingFixingFaceWidthOverride;

  PlasterRoom._({
    required super.id,
    required this.projectId,
    required this.name,
    required this.unitSystem,
    required this.ceilingHeight,
    required this.plasterCeiling,
    required this.ceilingSheetDirection,
    required this.ceilingFramingSpacingOverride,
    required this.ceilingFramingOffsetOverride,
    required this.ceilingFixingFaceWidthOverride,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterRoom.forInsert({
    required this.projectId,
    required this.name,
    required this.unitSystem,
    required this.ceilingHeight,
    this.plasterCeiling = true,
    this.ceilingSheetDirection = PlasterSheetDirection.auto,
    this.ceilingFramingSpacingOverride,
    this.ceilingFramingOffsetOverride,
    this.ceilingFixingFaceWidthOverride,
  }) : super.forInsert();

  PlasterRoom copyWith({
    int? projectId,
    String? name,
    PreferredUnitSystem? unitSystem,
    int? ceilingHeight,
    bool? plasterCeiling,
    PlasterSheetDirection? ceilingSheetDirection,
    Object? ceilingFramingSpacingOverride = _unsetPlasterRoomField,
    Object? ceilingFramingOffsetOverride = _unsetPlasterRoomField,
    Object? ceilingFixingFaceWidthOverride = _unsetPlasterRoomField,
  }) => PlasterRoom._(
    id: id,
    projectId: projectId ?? this.projectId,
    name: name ?? this.name,
    unitSystem: unitSystem ?? this.unitSystem,
    ceilingHeight: ceilingHeight ?? this.ceilingHeight,
    plasterCeiling: plasterCeiling ?? this.plasterCeiling,
    ceilingSheetDirection: ceilingSheetDirection ?? this.ceilingSheetDirection,
    ceilingFramingSpacingOverride:
        identical(ceilingFramingSpacingOverride, _unsetPlasterRoomField)
        ? this.ceilingFramingSpacingOverride
        : ceilingFramingSpacingOverride as int?,
    ceilingFramingOffsetOverride:
        identical(ceilingFramingOffsetOverride, _unsetPlasterRoomField)
        ? this.ceilingFramingOffsetOverride
        : ceilingFramingOffsetOverride as int?,
    ceilingFixingFaceWidthOverride:
        identical(ceilingFixingFaceWidthOverride, _unsetPlasterRoomField)
        ? this.ceilingFixingFaceWidthOverride
        : ceilingFixingFaceWidthOverride as int?,
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
    ceilingSheetDirection: PlasterSheetDirectionX.fromStorage(
      map['ceiling_sheet_direction'] as String?,
    ),
    ceilingFramingSpacingOverride:
        map['ceiling_framing_spacing_override'] as int?,
    ceilingFramingOffsetOverride:
        map['ceiling_framing_offset_override'] as int?,
    ceilingFixingFaceWidthOverride:
        map['ceiling_fixing_face_width_override'] as int?,
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
    'ceiling_sheet_direction': ceilingSheetDirection.storageValue,
    'ceiling_framing_spacing_override': ceilingFramingSpacingOverride,
    'ceiling_framing_offset_override': ceilingFramingOffsetOverride,
    'ceiling_fixing_face_width_override': ceilingFixingFaceWidthOverride,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
