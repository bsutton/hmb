import 'package:flutter/material.dart';

import 'room_canvas_models.dart';
import 'room_editor_forms.dart';
import 'room_editor_workspace.dart';

class RoomEditorPanel extends StatefulWidget {
  final int roomId;
  final RoomEditorUnitSystem unitSystem;
  final String unitLabel;
  final TextEditingController roomNameController;
  final TextEditingController ceilingHeightController;
  final TextEditingController? lineStudSpacingController;
  final TextEditingController? lineStudOffsetController;
  final ValueChanged<RoomEditorUnitSystem?> onUnitChanged;
  final Future<void> Function() onCommitRoomName;
  final Future<void> Function() onCommitCeilingHeight;
  final Future<void> Function()? onCommitSelectedLineOverrides;
  final RoomEditorDocument document;
  final bool landscape;
  final ValueChanged<RoomEditorDocument> onDocumentCommitted;
  final int? ceilingHeight;
  final ValueChanged<RoomEditorCommand>? onCommand;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final List<RoomEditorCustomTool> customTools;
  final Map<int, RoomEditorLinePresentation> linePresentations;
  final Map<int, RoomEditorIntersectionPresentation>
  intersectionPresentations;

  const RoomEditorPanel({
    required this.roomId,
    required this.unitSystem,
    required this.unitLabel,
    required this.roomNameController,
    required this.ceilingHeightController,
    required this.onUnitChanged,
    required this.onCommitRoomName,
    required this.onCommitCeilingHeight,
    required this.document,
    required this.onDocumentCommitted,
    this.ceilingHeight,
    super.key,
    this.lineStudSpacingController,
    this.lineStudOffsetController,
    this.onCommitSelectedLineOverrides,
    this.onCommand,
    this.onUndo,
    this.onRedo,
    this.landscape = false,
    this.customTools = const [],
    this.linePresentations = const {},
    this.intersectionPresentations = const {},
  });

  @override
  State<RoomEditorPanel> createState() => _RoomEditorPanelState();
}

class _RoomEditorPanelState extends State<RoomEditorPanel> {
  late final RoomEditorSelectionController _selectionController;

  @override
  void initState() {
    super.initState();
    _selectionController = RoomEditorSelectionController();
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<RoomEditorSelection>(
        valueListenable: _selectionController,
        builder: (context, selection, _) => RoomEditorDetailsForm(
          roomId: widget.roomId,
          unitSystem: widget.unitSystem,
          unitLabel: widget.unitLabel,
          roomNameController: widget.roomNameController,
          ceilingHeightController: widget.ceilingHeightController,
          selectedLineId: selection.selectedLineIndex == null
              ? null
              : widget.document.bundle.lines[selection.selectedLineIndex!].id,
          lineStudSpacingController: widget.lineStudSpacingController,
          lineStudOffsetController: widget.lineStudOffsetController,
          onUnitChanged: widget.onUnitChanged,
          onCommitRoomName: widget.onCommitRoomName,
          onCommitCeilingHeight: widget.onCommitCeilingHeight,
          onCommitSelectedLineOverrides: widget.onCommitSelectedLineOverrides,
          editorTools: const SizedBox.shrink(),
          canvas: RoomEditorWorkspace(
            document: widget.document,
            landscape: widget.landscape,
            selectionController: _selectionController,
            onDocumentCommitted: widget.onDocumentCommitted,
            ceilingHeight: widget.ceilingHeight,
            onCommand: widget.onCommand,
            onUndo: widget.onUndo,
            onRedo: widget.onRedo,
            customTools: widget.customTools,
            linePresentations: widget.linePresentations,
            intersectionPresentations: widget.intersectionPresentations,
          ),
        ),
      );
}
