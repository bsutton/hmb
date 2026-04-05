enum RoomEditorUnitSystem { metric, imperial }

enum RoomEditorOpeningType { door, window }

class RoomEditorIntPoint {
  final int x;
  final int y;

  const RoomEditorIntPoint(this.x, this.y);
}

class RoomEditorLine {
  final int id;
  final int seqNo;
  final int startX;
  final int startY;
  final int length;
  final bool plasterSelected;

  const RoomEditorLine({
    required this.id,
    required this.seqNo,
    required this.startX,
    required this.startY,
    required this.length,
    required this.plasterSelected,
  });

  RoomEditorLine copyWith({
    int? id,
    int? seqNo,
    int? startX,
    int? startY,
    int? length,
    bool? plasterSelected,
  }) => RoomEditorLine(
    id: id ?? this.id,
    seqNo: seqNo ?? this.seqNo,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    length: length ?? this.length,
    plasterSelected: plasterSelected ?? this.plasterSelected,
  );
}

class RoomEditorOpening {
  final int id;
  final int lineId;
  final RoomEditorOpeningType type;
  final int offsetFromStart;
  final int width;
  final int height;

  const RoomEditorOpening({
    required this.id,
    required this.lineId,
    required this.type,
    required this.offsetFromStart,
    required this.width,
    required this.height,
  });

  RoomEditorOpening copyWith({
    int? id,
    int? lineId,
    RoomEditorOpeningType? type,
    int? offsetFromStart,
    int? width,
    int? height,
  }) => RoomEditorOpening(
    id: id ?? this.id,
    lineId: lineId ?? this.lineId,
    type: type ?? this.type,
    offsetFromStart: offsetFromStart ?? this.offsetFromStart,
    width: width ?? this.width,
    height: height ?? this.height,
  );
}

class RoomEditorBundle {
  final String roomName;
  final RoomEditorUnitSystem unitSystem;
  final bool plasterCeiling;
  final List<RoomEditorLine> lines;
  final List<RoomEditorOpening> openings;

  const RoomEditorBundle({
    required this.roomName,
    required this.unitSystem,
    required this.plasterCeiling,
    required this.lines,
    required this.openings,
  });

  RoomEditorBundle copyWith({
    String? roomName,
    RoomEditorUnitSystem? unitSystem,
    bool? plasterCeiling,
    List<RoomEditorLine>? lines,
    List<RoomEditorOpening>? openings,
  }) => RoomEditorBundle(
    roomName: roomName ?? this.roomName,
    unitSystem: unitSystem ?? this.unitSystem,
    plasterCeiling: plasterCeiling ?? this.plasterCeiling,
    lines: lines ?? this.lines,
    openings: openings ?? this.openings,
  );
}
