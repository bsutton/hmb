import '../room_editor.dart';

typedef RoomEditorLineRecord = ({
  int id,
  int seqNo,
  int startX,
  int startY,
  int length,
});

typedef RoomEditorOpeningRecord = ({
  int id,
  int lineId,
  RoomEditorOpeningType type,
  int offsetFromStart,
  int width,
  int height,
  int sillHeight,
});

RoomEditorBundle buildRoomEditorBundle({
  required String roomName,
  required RoomEditorUnitSystem unitSystem,
  required bool plasterCeiling,
  required Iterable<RoomEditorLineRecord> lines,
  required Iterable<RoomEditorOpeningRecord> openings,
}) => RoomEditorBundle(
  roomName: roomName,
  unitSystem: unitSystem,
  plasterCeiling: plasterCeiling,
  lines: [
    for (final line in lines)
      RoomEditorLine(
        id: line.id,
        seqNo: line.seqNo,
        startX: line.startX,
        startY: line.startY,
        length: line.length,
      ),
  ],
  openings: [
    for (final opening in openings)
      RoomEditorOpening(
        id: opening.id,
        lineId: opening.lineId,
        type: opening.type,
        offsetFromStart: opening.offsetFromStart,
        width: opening.width,
        height: opening.height,
        sillHeight: opening.sillHeight,
      ),
  ],
);
