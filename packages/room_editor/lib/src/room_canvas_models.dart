import 'package:flutter/material.dart';

import '../room_editor.dart';

enum RoomEditorUnitSystem { metric, imperial }

enum RoomEditorOpeningType { door, window }

enum RoomEditorOpeningDimensionType {
  width,
  distanceToStartWall,
  distanceToEndWall,
}

enum RoomEditorGridControlsMode { none, gridOnly, gridAndSnap }

enum RoomEditorLineStrokeStyle { solid, dashed }

enum RoomEditorCustomToolSelectionRule {
  anySelection,
  singleLine,
  oneOrMoreLines,
  singleIntersection,
  oneOrMoreIntersections,
  twoAdjacentLines,
  twoNonAdjacentLines,
}

enum RoomEditorConstraintType {
  lineLength,
  horizontal,
  vertical,
  jointAngle,
  parallel,
}

typedef RoomEditorMoveIntersectionCallback =
    void Function(int index, RoomEditorIntPoint point);
typedef RoomEditorMoveLineCallback =
    void Function(int index, Offset worldDelta);
typedef RoomEditorMoveOpeningCallback =
    void Function(int index, RoomEditorIntPoint point, int anchorOffset);
typedef RoomEditorTapIndexedCallback = Future<void> Function(int index);
typedef RoomEditorTapCeilingCallback = Future<void> Function();
typedef RoomEditorTapConstraintCallback =
    Future<void> Function(RoomEditorConstraintKey key);
typedef RoomEditorTapOpeningDimensionCallback =
    Future<void> Function(RoomEditorOpeningDimensionKey key);
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
  final int? distanceToStartWall;
  final int? distanceToEndWall;

  const RoomEditorOpening({
    required this.id,
    required this.lineId,
    required this.type,
    required this.offsetFromStart,
    required this.width,
    required this.height,
    this.sillHeight = 0,
    this.distanceToStartWall,
    this.distanceToEndWall,
  });

  RoomEditorOpening copyWith({
    int? id,
    int? lineId,
    RoomEditorOpeningType? type,
    int? offsetFromStart,
    int? width,
    int? height,
    int? sillHeight,
    int? distanceToStartWall,
    bool clearDistanceToStartWall = false,
    int? distanceToEndWall,
    bool clearDistanceToEndWall = false,
  }) => RoomEditorOpening(
    id: id ?? this.id,
    lineId: lineId ?? this.lineId,
    type: type ?? this.type,
    offsetFromStart: offsetFromStart ?? this.offsetFromStart,
    width: width ?? this.width,
    height: height ?? this.height,
    sillHeight: sillHeight ?? this.sillHeight,
    distanceToStartWall: clearDistanceToStartWall
        ? null
        : distanceToStartWall ?? this.distanceToStartWall,
    distanceToEndWall: clearDistanceToEndWall
        ? null
        : distanceToEndWall ?? this.distanceToEndWall,
  );
}

@immutable
class RoomEditorOpeningDimensionKey {
  final int openingId;
  final RoomEditorOpeningDimensionType type;

  const RoomEditorOpeningDimensionKey({
    required this.openingId,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomEditorOpeningDimensionKey &&
          openingId == other.openingId &&
          type == other.type;

  @override
  int get hashCode => Object.hash(openingId, type);
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
  final int? distanceToStartWall;
  final int? distanceToEndWall;

  const RoomEditorOpeningDraft({
    required this.type,
    required this.width,
    required this.height,
    this.sillHeight = 0,
    this.distanceToStartWall,
    this.distanceToEndWall,
  });
}


class RoomEditorAnnotationBadge {
  final String id;
  final String? text;
  final IconData? icon;
  final Color? color;
  final bool constraintLike;

  const RoomEditorAnnotationBadge({
    required this.id,
    this.text,
    this.icon,
    this.color,
    this.constraintLike = false,
  }) : assert(
         text != null || icon != null,
         'Either text or icon must be provided',
       );
}

class RoomEditorLinePresentation {
  final RoomEditorLineStrokeStyle style;
  final Color? color;
  final RoomEditorAnnotationBadge? badge;

  const RoomEditorLinePresentation({
    this.style = RoomEditorLineStrokeStyle.solid,
    this.color,
    this.badge,
  });
}

class RoomEditorIntersectionPresentation {
  final Color? color;
  final RoomEditorAnnotationBadge? badge;

  const RoomEditorIntersectionPresentation({this.color, this.badge});
}

class RoomEditorCustomToolContext {
  final RoomEditorDocument document;
  final RoomEditorSelection selection;

  const RoomEditorCustomToolContext({
    required this.document,
    required this.selection,
  });
}

class RoomEditorCustomToolInvocation {
  final String toolId;
  final RoomEditorDocument document;
  final RoomEditorSelection selection;

  const RoomEditorCustomToolInvocation({
    required this.toolId,
    required this.document,
    required this.selection,
  });
}

class RoomEditorCustomTool {
  final String id;
  final String label;
  final String helpText;
  final IconData? icon;
  final Widget? iconWidget;
  final RoomEditorCustomToolSelectionRule selectionRule;
  final bool Function(RoomEditorCustomToolContext context)? isSelected;
  final bool Function(RoomEditorCustomToolContext context)? isEnabled;
  final Future<void> Function(RoomEditorCustomToolInvocation invocation)
  onInvoked;

  const RoomEditorCustomTool({
    required this.id,
    required this.label,
    required this.helpText,
    required this.selectionRule,
    required this.onInvoked,
    this.icon,
    this.iconWidget,
    this.isSelected,
    this.isEnabled,
  }) : assert(
         icon != null || iconWidget != null,
         'Either icon or iconWidget must be provided',
       );
}

class RoomEditorSelection {
  final Set<int> selectedLineIndices;
  final Set<int> selectedIntersectionIndices;
  final int? selectedOpeningIndex;
  final RoomEditorConstraintKey? selectedConstraintKey;
  final RoomEditorOpeningDimensionKey? selectedOpeningDimensionKey;

  RoomEditorSelection({
    int? selectedLineIndex,
    Iterable<int> selectedLineIndices = const <int>[],
    int? selectedIntersectionIndex,
    Iterable<int> selectedIntersectionIndices = const <int>[],
    this.selectedOpeningIndex,
    this.selectedConstraintKey,
    this.selectedOpeningDimensionKey,
  }) : selectedLineIndices = {
         if (selectedLineIndex != null) selectedLineIndex,
         ...selectedLineIndices,
       },
       selectedIntersectionIndices = {
         if (selectedIntersectionIndex != null) selectedIntersectionIndex,
         ...selectedIntersectionIndices,
       };

  const RoomEditorSelection.empty()
    : selectedLineIndices = const {},
      selectedIntersectionIndices = const {},
      selectedOpeningIndex = null,
      selectedConstraintKey = null,
      selectedOpeningDimensionKey = null;

  int? get selectedLineIndex =>
      selectedLineIndices.length == 1 ? selectedLineIndices.first : null;

  int? get selectedIntersectionIndex => selectedIntersectionIndices.length == 1
      ? selectedIntersectionIndices.first
      : null;
}

int openingDistanceToEndWall(RoomEditorOpening opening, RoomEditorLine line) =>
    (line.length - opening.offsetFromStart - opening.width).clamp(
      0,
      line.length,
    );

RoomEditorOpening normalizeOpeningForLine(
  RoomEditorOpening opening,
  RoomEditorLine line,
) {
  final maxOffset = (line.length - opening.width).clamp(0, line.length);
  if (opening.distanceToStartWall != null) {
    return opening.copyWith(
      offsetFromStart: opening.distanceToStartWall!.clamp(0, maxOffset),
    );
  }
  if (opening.distanceToEndWall != null) {
    return opening.copyWith(
      offsetFromStart:
          (line.length - opening.width - opening.distanceToEndWall!).clamp(
            0,
            maxOffset,
          ),
    );
  }
  return opening.copyWith(
    offsetFromStart: opening.offsetFromStart.clamp(0, maxOffset),
  );
}

RoomEditorDocument normalizeRoomEditorOpenings(RoomEditorDocument document) {
  final openings = [
    for (final opening in document.bundle.openings)
      () {
        for (final line in document.bundle.lines) {
          if (line.id == opening.lineId) {
            return normalizeOpeningForLine(opening, line);
          }
        }
        return opening;
      }(),
  ];
  return document.copyWith(
    bundle: document.bundle.copyWith(openings: openings),
  );
}

List<RoomEditorConstraint> effectiveRoomEditorConstraints(
  RoomEditorDocument document,
) {
  final constraints = <RoomEditorConstraint>[...document.constraints];
  for (final opening in document.bundle.openings) {
    final startDistance = opening.distanceToStartWall;
    final endDistance = opening.distanceToEndWall;
    if (startDistance == null || endDistance == null) {
      continue;
    }
    constraints.add(
      RoomEditorConstraint(
        lineId: opening.lineId,
        type: RoomEditorConstraintType.lineLength,
        targetValue: startDistance + opening.width + endDistance,
      ),
    );
  }
  return constraints;
}


bool canApplyRoomEditorCustomTool({
  required RoomEditorCustomTool tool,
  required RoomEditorDocument document,
  required RoomEditorSelection selection,
}) {
  final context = RoomEditorCustomToolContext(
    document: document,
    selection: selection,
  );
  if (tool.isEnabled != null && !tool.isEnabled!(context)) {
    return false;
  }
  final lineCount = document.bundle.lines.length;
  final selectedLines = selection.selectedLineIndices;
  final selectedIntersections = selection.selectedIntersectionIndices;
  switch (tool.selectionRule) {
    case RoomEditorCustomToolSelectionRule.anySelection:
      return selectedLines.isNotEmpty || selectedIntersections.isNotEmpty;
    case RoomEditorCustomToolSelectionRule.singleLine:
      return selectedLines.length == 1;
    case RoomEditorCustomToolSelectionRule.oneOrMoreLines:
      return selectedLines.isNotEmpty;
    case RoomEditorCustomToolSelectionRule.singleIntersection:
      return selectedIntersections.length == 1;
    case RoomEditorCustomToolSelectionRule.oneOrMoreIntersections:
      return selectedIntersections.isNotEmpty;
    case RoomEditorCustomToolSelectionRule.twoAdjacentLines:
      if (selectedLines.length != 2 || lineCount < 2) {
        return false;
      }
      final ordered = selectedLines.toList()..sort();
      return (ordered[0] + 1) % lineCount == ordered[1] ||
          (ordered[1] + 1) % lineCount == ordered[0];
    case RoomEditorCustomToolSelectionRule.twoNonAdjacentLines:
      if (selectedLines.length != 2 || lineCount < 2) {
        return false;
      }
      final ordered = selectedLines.toList()..sort();
      return (ordered[0] + 1) % lineCount != ordered[1] &&
          (ordered[1] + 1) % lineCount != ordered[0];
  }
}

class RoomEditorSelectionController extends ValueNotifier<RoomEditorSelection> {
  RoomEditorSelectionController([
    super.value = const RoomEditorSelection.empty(),
  ]);
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
  final VoidCallback onStartMoveLine;
  final RoomEditorMoveLineCallback onMoveLine;
  final Future<void> Function() onEndMoveLine;
  final VoidCallback onStartMoveOpening;
  final RoomEditorMoveOpeningCallback onMoveOpening;
  final Future<void> Function() onEndMoveOpening;
  final RoomEditorTapIndexedCallback onTapIntersection;
  final RoomEditorTapIndexedCallback onTapOpening;
  final RoomEditorTapIndexedCallback onTapLine;
  final RoomEditorTapCeilingCallback onTapCeiling;
  final RoomEditorTapConstraintCallback onTapConstraint;
  final RoomEditorTapOpeningDimensionCallback onTapOpeningDimension;
  final RoomEditorMoveConstraintCallback onMoveConstraint;
  final RoomEditorDeleteConstraintCallback onDeleteConstraint;

  const RoomEditorCanvasCallbacks({
    required this.onStartMoveIntersection,
    required this.onMoveIntersection,
    required this.onEndMoveIntersection,
    required this.onStartMoveLine,
    required this.onMoveLine,
    required this.onEndMoveLine,
    required this.onStartMoveOpening,
    required this.onMoveOpening,
    required this.onEndMoveOpening,
    required this.onTapIntersection,
    required this.onTapOpening,
    required this.onTapLine,
    required this.onTapCeiling,
    required this.onTapConstraint,
    required this.onTapOpeningDimension,
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
