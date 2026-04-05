enum RoomEditorUnitSystem { metric, imperial }

enum RoomEditorOpeningType { door, window }

enum RoomEditorConstraintType { lineLength, horizontal, vertical, jointAngle }

typedef RoomEditorMoveIntersectionCallback =
    void Function(int index, RoomEditorIntPoint point);
typedef RoomEditorMoveOpeningCallback =
    void Function(int index, RoomEditorIntPoint point, int anchorOffset);
typedef RoomEditorTapIndexedCallback = Future<void> Function(int index);
typedef RoomEditorTapCeilingCallback = Future<void> Function();

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

class RoomEditorConstraint {
  final int lineId;
  final RoomEditorConstraintType type;
  final int? targetValue;

  const RoomEditorConstraint({
    required this.lineId,
    required this.type,
    this.targetValue,
  });
}

class RoomEditorDocument {
  final RoomEditorBundle bundle;
  final List<RoomEditorConstraint> constraints;

  const RoomEditorDocument({
    required this.bundle,
    required this.constraints,
  });

  RoomEditorDocument copyWith({
    RoomEditorBundle? bundle,
    List<RoomEditorConstraint>? constraints,
  }) => RoomEditorDocument(
    bundle: bundle ?? this.bundle,
    constraints: constraints ?? this.constraints,
  );
}

class RoomEditorSelection {
  final int? selectedLineIndex;
  final int? selectedIntersectionIndex;
  final int? selectedOpeningIndex;

  const RoomEditorSelection({
    this.selectedLineIndex,
    this.selectedIntersectionIndex,
    this.selectedOpeningIndex,
  });
}

class RoomEditorCanvasCallbacks {
  final VoidCallback onStartMoveIntersection;
  final RoomEditorMoveIntersectionCallback onMoveIntersection;
  final Future<void> Function() onEndMoveIntersection;
  final VoidCallback onStartMoveOpening;
  final RoomEditorMoveOpeningCallback onMoveOpening;
  final Future<void> Function() onEndMoveOpening;
  final RoomEditorTapIndexedCallback onTapIntersection;
  final RoomEditorTapIndexedCallback onTapOpening;
  final RoomEditorTapIndexedCallback onTapLine;
  final RoomEditorTapCeilingCallback onTapCeiling;

  const RoomEditorCanvasCallbacks({
    required this.onStartMoveIntersection,
    required this.onMoveIntersection,
    required this.onEndMoveIntersection,
    required this.onStartMoveOpening,
    required this.onMoveOpening,
    required this.onEndMoveOpening,
    required this.onTapIntersection,
    required this.onTapOpening,
    required this.onTapLine,
    required this.onTapCeiling,
  });
}

enum RoomEditorCommandType {
  splitLine,
  addDoor,
  addWindow,
  editOpening,
  deleteOpening,
  editLineLength,
  jointAction,
  editAngle,
}

class RoomEditorCommand {
  final RoomEditorCommandType type;
  final int? lineIndex;
  final int? openingIndex;
  final int? intersectionIndex;
  final RoomEditorDocument document;

  const RoomEditorCommand({
    required this.type,
    required this.document,
    this.lineIndex,
    this.openingIndex,
    this.intersectionIndex,
  });
}
