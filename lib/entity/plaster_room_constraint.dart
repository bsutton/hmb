/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import 'entity.dart';

enum PlasterConstraintType { lineLength, horizontal, vertical, jointAngle }

class PlasterRoomConstraint extends Entity<PlasterRoomConstraint> {
  final int roomId;
  final int lineId;
  final PlasterConstraintType type;
  final int? targetValue;

  PlasterRoomConstraint._({
    required super.id,
    required this.roomId,
    required this.lineId,
    required this.type,
    required this.targetValue,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterRoomConstraint.forInsert({
    required this.roomId,
    required this.lineId,
    required this.type,
    this.targetValue,
  }) : super.forInsert();

  PlasterRoomConstraint copyWith({
    int? roomId,
    int? lineId,
    PlasterConstraintType? type,
    int? targetValue,
    bool clearTargetValue = false,
  }) => PlasterRoomConstraint._(
    id: id,
    roomId: roomId ?? this.roomId,
    lineId: lineId ?? this.lineId,
    type: type ?? this.type,
    targetValue: clearTargetValue ? null : targetValue ?? this.targetValue,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterRoomConstraint.fromMap(Map<String, dynamic> map) =>
      PlasterRoomConstraint._(
        id: map['id'] as int,
        roomId: map['room_id'] as int,
        lineId: map['line_id'] as int,
        type: PlasterConstraintType.values.byName(
          map['type'] as String? ?? PlasterConstraintType.lineLength.name,
        ),
        targetValue: map['target_value'] as int?,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'room_id': roomId,
    'line_id': lineId,
    'type': type.name,
    'target_value': targetValue,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
