/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import '../util/dart/plaster_sheet_direction.dart';
import 'entity.dart';

const _unsetPlasterRoomLineField = Object();

class PlasterRoomLine extends Entity<PlasterRoomLine> {
  final int roomId;
  final int seqNo;
  final int startX;
  final int startY;
  final int length;
  final bool plasterSelected;
  final PlasterSheetDirection sheetDirection;
  final int? studSpacingOverride;
  final int? studOffsetOverride;
  final int? fixingFaceWidthOverride;

  PlasterRoomLine._({
    required super.id,
    required this.roomId,
    required this.seqNo,
    required this.startX,
    required this.startY,
    required this.length,
    required this.plasterSelected,
    required this.sheetDirection,
    required this.studSpacingOverride,
    required this.studOffsetOverride,
    required this.fixingFaceWidthOverride,
    required super.createdDate,
    required super.modifiedDate,
  });

  PlasterRoomLine.forInsert({
    required this.roomId,
    required this.seqNo,
    required this.startX,
    required this.startY,
    required this.length,
    this.plasterSelected = true,
    this.sheetDirection = PlasterSheetDirection.auto,
    this.studSpacingOverride,
    this.studOffsetOverride,
    this.fixingFaceWidthOverride,
  }) : super.forInsert();

  PlasterRoomLine copyWith({
    int? roomId,
    int? seqNo,
    int? startX,
    int? startY,
    int? length,
    bool? plasterSelected,
    PlasterSheetDirection? sheetDirection,
    Object? studSpacingOverride = _unsetPlasterRoomLineField,
    Object? studOffsetOverride = _unsetPlasterRoomLineField,
    Object? fixingFaceWidthOverride = _unsetPlasterRoomLineField,
  }) => PlasterRoomLine._(
    id: id,
    roomId: roomId ?? this.roomId,
    seqNo: seqNo ?? this.seqNo,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    length: length ?? this.length,
    plasterSelected: plasterSelected ?? this.plasterSelected,
    sheetDirection: sheetDirection ?? this.sheetDirection,
    studSpacingOverride:
        identical(studSpacingOverride, _unsetPlasterRoomLineField)
        ? this.studSpacingOverride
        : studSpacingOverride as int?,
    studOffsetOverride:
        identical(studOffsetOverride, _unsetPlasterRoomLineField)
        ? this.studOffsetOverride
        : studOffsetOverride as int?,
    fixingFaceWidthOverride:
        identical(fixingFaceWidthOverride, _unsetPlasterRoomLineField)
        ? this.fixingFaceWidthOverride
        : fixingFaceWidthOverride as int?,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PlasterRoomLine.fromMap(Map<String, dynamic> map) =>
      PlasterRoomLine._(
        id: map['id'] as int,
        roomId: map['room_id'] as int,
        seqNo: map['seq_no'] as int? ?? 0,
        startX: map['start_x'] as int? ?? 0,
        startY: map['start_y'] as int? ?? 0,
        length: map['length'] as int? ?? 0,
        plasterSelected: (map['plaster_selected'] as int? ?? 1) == 1,
        sheetDirection: PlasterSheetDirectionX.fromStorage(
          map['sheet_direction'] as String?,
        ),
        studSpacingOverride: map['stud_spacing_override'] as int?,
        studOffsetOverride: map['stud_offset_override'] as int?,
        fixingFaceWidthOverride: map['fixing_face_width_override'] as int?,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'room_id': roomId,
    'seq_no': seqNo,
    'start_x': startX,
    'start_y': startY,
    'length': length,
    'plaster_selected': plasterSelected ? 1 : 0,
    'sheet_direction': sheetDirection.storageValue,
    'stud_spacing_override': studSpacingOverride,
    'stud_offset_override': studOffsetOverride,
    'fixing_face_width_override': fixingFaceWidthOverride,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
