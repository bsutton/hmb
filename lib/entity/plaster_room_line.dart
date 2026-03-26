/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import '../util/dart/plaster_sheet_direction.dart';
import 'entity.dart';

class PlasterRoomLine extends Entity<PlasterRoomLine> {
  final int roomId;
  final int seqNo;
  final int startX;
  final int startY;
  final int length;
  final bool plasterSelected;
  final PlasterSheetDirection sheetDirection;

  PlasterRoomLine._({
    required super.id,
    required this.roomId,
    required this.seqNo,
    required this.startX,
    required this.startY,
    required this.length,
    required this.plasterSelected,
    required this.sheetDirection,
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
  }) : super.forInsert();

  PlasterRoomLine copyWith({
    int? roomId,
    int? seqNo,
    int? startX,
    int? startY,
    int? length,
    bool? plasterSelected,
    PlasterSheetDirection? sheetDirection,
  }) => PlasterRoomLine._(
    id: id,
    roomId: roomId ?? this.roomId,
    seqNo: seqNo ?? this.seqNo,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    length: length ?? this.length,
    plasterSelected: plasterSelected ?? this.plasterSelected,
    sheetDirection: sheetDirection ?? this.sheetDirection,
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
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
