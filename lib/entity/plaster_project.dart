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

import 'entity.dart';

const _unsetPlasterProjectField = Object();

class PlasterProject extends Entity<PlasterProject> {
  final String name;
  final int jobId;
  final int? taskId;
  final int? supplierId;
  final int wastePercent;
  final int wallStudSpacing;
  final int wallStudOffset;
  final int wallFixingFaceWidth;
  final int ceilingFramingSpacing;
  final int ceilingFramingOffset;
  final int ceilingFixingFaceWidth;

  PlasterProject._({
    required super.id,
    required this.name,
    required this.jobId,
    required this.taskId,
    required this.supplierId,
    required this.wastePercent,
    required this.wallStudSpacing,
    required this.wallStudOffset,
    required this.wallFixingFaceWidth,
    required this.ceilingFramingSpacing,
    required this.ceilingFramingOffset,
    required this.ceilingFixingFaceWidth,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterProject.forInsert({
    required this.name,
    required this.jobId,
    required this.wastePercent,
    this.taskId,
    this.supplierId,
    this.wallStudSpacing = 6000,
    this.wallStudOffset = 0,
    this.wallFixingFaceWidth = 450,
    this.ceilingFramingSpacing = 4500,
    this.ceilingFramingOffset = 0,
    this.ceilingFixingFaceWidth = 450,
  }) : super.forInsert();

  PlasterProject copyWith({
    String? name,
    int? jobId,
    Object? taskId = _unsetPlasterProjectField,
    Object? supplierId = _unsetPlasterProjectField,
    int? wastePercent,
    int? wallStudSpacing,
    int? wallStudOffset,
    int? wallFixingFaceWidth,
    int? ceilingFramingSpacing,
    int? ceilingFramingOffset,
    int? ceilingFixingFaceWidth,
  }) => PlasterProject._(
    id: id,
    name: name ?? this.name,
    jobId: jobId ?? this.jobId,
    taskId: identical(taskId, _unsetPlasterProjectField)
        ? this.taskId
        : taskId as int?,
    supplierId: identical(supplierId, _unsetPlasterProjectField)
        ? this.supplierId
        : supplierId as int?,
    wastePercent: wastePercent ?? this.wastePercent,
    wallStudSpacing: wallStudSpacing ?? this.wallStudSpacing,
    wallStudOffset: wallStudOffset ?? this.wallStudOffset,
    wallFixingFaceWidth: wallFixingFaceWidth ?? this.wallFixingFaceWidth,
    ceilingFramingSpacing: ceilingFramingSpacing ?? this.ceilingFramingSpacing,
    ceilingFramingOffset: ceilingFramingOffset ?? this.ceilingFramingOffset,
    ceilingFixingFaceWidth:
        ceilingFixingFaceWidth ?? this.ceilingFixingFaceWidth,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterProject.fromMap(Map<String, dynamic> map) => PlasterProject._(
    id: map['id'] as int,
    name: map['name'] as String? ?? '',
    jobId: map['job_id'] as int,
    taskId: map['task_id'] as int?,
    supplierId: map['supplier_id'] as int?,
    wastePercent: map['waste_percent'] as int? ?? 15,
    wallStudSpacing: map['wall_stud_spacing'] as int? ?? 6000,
    wallStudOffset: map['wall_stud_offset'] as int? ?? 0,
    wallFixingFaceWidth: map['wall_fixing_face_width'] as int? ?? 450,
    ceilingFramingSpacing: map['ceiling_framing_spacing'] as int? ?? 4500,
    ceilingFramingOffset: map['ceiling_framing_offset'] as int? ?? 0,
    ceilingFixingFaceWidth: map['ceiling_fixing_face_width'] as int? ?? 450,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'job_id': jobId,
    'task_id': taskId,
    'supplier_id': supplierId,
    'waste_percent': wastePercent,
    'wall_stud_spacing': wallStudSpacing,
    'wall_stud_offset': wallStudOffset,
    'wall_fixing_face_width': wallFixingFaceWidth,
    'ceiling_framing_spacing': ceilingFramingSpacing,
    'ceiling_framing_offset': ceilingFramingOffset,
    'ceiling_fixing_face_width': ceilingFixingFaceWidth,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
