import 'package:flutter/material.dart';

import '../room_editor.dart';

enum RoomEditorUnitSystem { metric, imperial }

enum RoomEditorOpeningType { door, window }

enum RoomEditorConstraintType { lineLength, horizontal, vertical, jointAngle }

typedef RoomEditorMoveIntersectionCallback =
    void Function(int index, RoomEditorIntPoint point);
typedef RoomEditorMoveOpeningCallback =
    void Function(int index, RoomEditorIntPoint point, int anchorOffset);
typedef RoomEditorTapIndexedCallback = Future<void> Function(int index);
typedef RoomEditorTapCeilingCallback = Future<void> Function();
typedef RoomEditorTapConstraintCallback =
    Future<void> Function(RoomEditorConstraintKey key);
typedef RoomEditorMoveConstraintCallback =
    void Function(RoomEditorConstraintKey key, Offset worldOffset);
typedef RoomEditorDeleteConstraintCallback =
    Future<void> Function(RoomEditorConstraintKey key);

class RoomEditorIntPoint {
  final int x;
  final int y;

  const RoomEditorIntPoint(this.x, this.y);

  @override
  String toString() => '($x, $y)';
}

class RoomEditorOpening {
  final int id;
  final int lineId;
  final RoomEditorOpeningType type;
  final int offsetFromStart;
  final int width;
  final int height;
  final int sillHeight;

  const RoomEditorOpening({
    required this.id,
    required this.lineId,
    required this.type,
    required this.offsetFromStart,
    required this.width,
    required this.height,
    this.sillHeight = 0,
  });

  RoomEditorOpening copyWith({
    int? id,
    int? lineId,
    RoomEditorOpeningType? type,
    int? offsetFromStart,
    int? width,
    int? height,
    int? sillHeight,
  }) => RoomEditorOpening(
    id: id ?? this.id,
    lineId: lineId ?? this.lineId,
    type: type ?? this.type,
    offsetFromStart: offsetFromStart ?? this.offsetFromStart,
    width: width ?? this.width,
    height: height ?? this.height,
    sillHeight: sillHeight ?? this.sillHeight,
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

@immutable
class RoomEditorConstraintKey {
  final int lineId;
  final RoomEditorConstraintType type;

  const RoomEditorConstraintKey({required this.lineId, required this.type});

  factory RoomEditorConstraintKey.fromConstraint(
    RoomEditorConstraint constraint,
  ) =>
      RoomEditorConstraintKey(lineId: constraint.lineId, type: constraint.type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomEditorConstraintKey &&
          lineId == other.lineId &&
          type == other.type;

  @override
  int get hashCode => Object.hash(lineId, type);
}

class RoomEditorDocument {
  final RoomEditorBundle bundle;
  final List<RoomEditorConstraint> constraints;

  const RoomEditorDocument({required this.bundle, required this.constraints});

  RoomEditorDocument copyWith({
    RoomEditorBundle? bundle,
    List<RoomEditorConstraint>? constraints,
  }) => RoomEditorDocument(
    bundle: bundle ?? this.bundle,
    constraints: constraints ?? this.constraints,
  );
}

class RoomEditorOpeningDraft {
  final RoomEditorOpeningType type;
  final int width;
  final int height;
  final int sillHeight;

  const RoomEditorOpeningDraft({
    required this.type,
    required this.width,
    required this.height,
    this.sillHeight = 0,
  });
}

class RoomEditorSelection {
  final int? selectedLineIndex;
  final int? selectedIntersectionIndex;
  final int? selectedOpeningIndex;
  final RoomEditorConstraintKey? selectedConstraintKey;

  const RoomEditorSelection({
    this.selectedLineIndex,
    this.selectedIntersectionIndex,
    this.selectedOpeningIndex,
    this.selectedConstraintKey,
  });
}

class RoomEditorSelectionController extends ValueNotifier<RoomEditorSelection> {
  RoomEditorSelectionController([super.value = const RoomEditorSelection()]);
}

class RoomEditorHistory {
  final List<RoomEditorDocument> undoStack;
  final List<RoomEditorDocument> redoStack;

  const RoomEditorHistory({
    this.undoStack = const [],
    this.redoStack = const [],
  });

  RoomEditorHistory copyWith({
    List<RoomEditorDocument>? undoStack,
    List<RoomEditorDocument>? redoStack,
  }) => RoomEditorHistory(
    undoStack: undoStack ?? this.undoStack,
    redoStack: redoStack ?? this.redoStack,
  );
}

class RoomEditorHistoryController extends ValueNotifier<RoomEditorHistory> {
  RoomEditorHistoryController([super.value = const RoomEditorHistory()]);
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
  final RoomEditorTapConstraintCallback onTapConstraint;
  final RoomEditorMoveConstraintCallback onMoveConstraint;
  final RoomEditorDeleteConstraintCallback onDeleteConstraint;

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
    required this.onTapConstraint,
    required this.onMoveConstraint,
    required this.onDeleteConstraint,
  });
}

enum RoomEditorCommandType {
  splitLine,
  addOpening,
  editOpening,
  deleteOpening,
  setLineLength,
  removeLineLength,
  joinIntersection,
  setAngle,
  removeAngle,
}

class RoomEditorCommand {
  final RoomEditorCommandType type;
  final int? lineIndex;
  final int? openingIndex;
  final int? intersectionIndex;
  final int? intValue;
  final RoomEditorOpeningDraft? openingDraft;
  final RoomEditorDocument document;

  const RoomEditorCommand({
    required this.type,
    required this.document,
    this.lineIndex,
    this.openingIndex,
    this.intersectionIndex,
    this.intValue,
    this.openingDraft,
  });
}
