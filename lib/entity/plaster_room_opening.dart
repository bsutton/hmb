/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import 'entity.dart';

enum PlasterOpeningType { door, window }

class PlasterRoomOpening extends Entity<PlasterRoomOpening> {
  final int lineId;
  final PlasterOpeningType type;
  final int offsetFromStart;
  final int width;
  final int height;
  final int sillHeight;

  PlasterRoomOpening._({
    required super.id,
    required this.lineId,
    required this.type,
    required this.offsetFromStart,
    required this.width,
    required this.height,
    required this.sillHeight,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterRoomOpening.forInsert({
    required this.lineId,
    required this.type,
    required this.offsetFromStart,
    required this.width,
    required this.height,
    required this.sillHeight,
  }) : super.forInsert();

  PlasterRoomOpening copyWith({
    int? lineId,
    PlasterOpeningType? type,
    int? offsetFromStart,
    int? width,
    int? height,
    int? sillHeight,
  }) => PlasterRoomOpening._(
    id: id,
    lineId: lineId ?? this.lineId,
    type: type ?? this.type,
    offsetFromStart: offsetFromStart ?? this.offsetFromStart,
    width: width ?? this.width,
    height: height ?? this.height,
    sillHeight: sillHeight ?? this.sillHeight,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterRoomOpening.fromMap(Map<String, dynamic> map) =>
      PlasterRoomOpening._(
        id: map['id'] as int,
        lineId: map['line_id'] as int,
        type: (map['type'] as String?) == 'window'
            ? PlasterOpeningType.window
            : PlasterOpeningType.door,
        offsetFromStart: map['offset_from_start'] as int? ?? 0,
        width: map['width'] as int? ?? 0,
        height: map['height'] as int? ?? 0,
        sillHeight: map['sill_height'] as int? ?? 0,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'line_id': lineId,
    'type': type.name,
    'offset_from_start': offsetFromStart,
    'width': width,
    'height': height,
    'sill_height': sillHeight,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
