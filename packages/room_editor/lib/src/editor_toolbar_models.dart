import 'package:flutter/material.dart';

class RoomEditorToolAction {
  final String id;
  final String label;
  final String helpText;
  final bool enabled;
  final bool selected;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;

  const RoomEditorToolAction({
    required this.id,
    required this.label,
    required this.helpText,
    this.enabled = true,
    this.selected = false,
    this.icon,
    this.iconWidget,
    this.onPressed,
  }) : assert(
         icon != null || iconWidget != null,
         'Either icon or iconWidget must be provided',
       );
}

class RoomEditorToolbarState {
  final bool selectionMode;
  final bool snapToGrid;
  final bool showGrid;
  final bool hasLine;
  final bool hasIntersection;
  final bool hasOpening;
  final bool hasLineLengthConstraint;
  final bool hasHorizontalConstraint;
  final bool hasVerticalConstraint;
  final bool hasAngleConstraint;
  final bool showAllConstraints;
  final bool isSelectedLinePlaster;
  final bool isSelectedOpeningDoor;

  const RoomEditorToolbarState({
    required this.selectionMode,
    required this.snapToGrid,
    required this.showGrid,
    required this.hasLine,
    required this.hasIntersection,
    required this.hasOpening,
    required this.hasLineLengthConstraint,
    required this.hasHorizontalConstraint,
    required this.hasVerticalConstraint,
    required this.hasAngleConstraint,
    required this.showAllConstraints,
    required this.isSelectedLinePlaster,
    required this.isSelectedOpeningDoor,
  });
}

class RoomEditorToolbarCallbacks {
  final VoidCallback onToggleSelectionMode;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onFit;
  final VoidCallback onToggleSnapToGrid;
  final VoidCallback onToggleShowGrid;
  final VoidCallback onDeselect;
  final VoidCallback? onSplit;
  final VoidCallback? onAddDoor;
  final VoidCallback? onAddWindow;
  final VoidCallback? onEditOpening;
  final VoidCallback? onDeleteOpening;
  final VoidCallback? onToggleLinePlaster;
  final VoidCallback? onSetLineLength;
  final VoidCallback? onSetHorizontal;
  final VoidCallback? onSetVertical;
  final VoidCallback? onJointAction;
  final VoidCallback? onSetAngle;
  final VoidCallback onToggleShowAllConstraints;

  const RoomEditorToolbarCallbacks({
    required this.onToggleSelectionMode,
    required this.onUndo,
    required this.onRedo,
    required this.onFit,
    required this.onToggleSnapToGrid,
    required this.onToggleShowGrid,
    required this.onDeselect,
    required this.onSplit,
    required this.onAddDoor,
    required this.onAddWindow,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onToggleLinePlaster,
    required this.onSetLineLength,
    required this.onSetHorizontal,
    required this.onSetVertical,
    required this.onJointAction,
    required this.onSetAngle,
    required this.onToggleShowAllConstraints,
  });
}

List<RoomEditorToolAction> buildRoomEditorToolbarActions({
  required RoomEditorToolbarState state,
  required RoomEditorToolbarCallbacks callbacks,
  bool constraintsOnly = false,
  bool excludeConstraints = false,
}) {
  final primaryButtons = <RoomEditorToolAction>[
    RoomEditorToolAction(
      id: 'toggle-selection-mode',
      icon: state.selectionMode ? Icons.touch_app : Icons.ads_click,
      label: state.selectionMode ? 'Select Mode' : 'Edit Mode',
      helpText:
          'Toggle between selection mode and direct geometry editing. '
          'Selection mode lets you pick walls, joints, and openings so you '
          'can apply tools to them.',
      selected: state.selectionMode,
      onPressed: callbacks.onToggleSelectionMode,
    ),
    RoomEditorToolAction(
      id: 'undo',
      icon: Icons.undo,
      label: 'Undo',
      helpText:
          'Restore the previous room-editing step, including geometry and '
          'openings.',
      enabled: callbacks.onUndo != null,
      onPressed: callbacks.onUndo,
    ),
    RoomEditorToolAction(
      id: 'redo',
      icon: Icons.redo,
      label: 'Redo',
      helpText: 'Reapply the most recently undone room-editing step.',
      enabled: callbacks.onRedo != null,
      onPressed: callbacks.onRedo,
    ),
    RoomEditorToolAction(
      id: 'fit',
      icon: Icons.fit_screen,
      label: 'Fit',
      helpText:
          'Reset the drawing zoom and pan so the current room fits back into '
          'view.',
      onPressed: callbacks.onFit,
    ),
    RoomEditorToolAction(
      id: 'toggle-snap',
      icon: state.snapToGrid ? Icons.grid_on : Icons.grid_off,
      label: state.snapToGrid ? 'Snap On' : 'Snap Off',
      helpText: 'Turn grid snapping on or off when moving points and openings.',
      selected: state.snapToGrid,
      onPressed: callbacks.onToggleSnapToGrid,
    ),
    RoomEditorToolAction(
      id: 'toggle-grid',
      icon: state.showGrid ? Icons.border_all : Icons.border_clear,
      label: state.showGrid ? 'Grid On' : 'Grid Off',
      helpText: 'Show or hide the background drawing grid.',
      selected: state.showGrid,
      onPressed: callbacks.onToggleShowGrid,
    ),
    RoomEditorToolAction(
      id: 'deselect',
      icon: Icons.deselect,
      label: 'Deselect',
      helpText: 'Clear the current wall, joint, or opening selection.',
      enabled: state.hasLine || state.hasIntersection || state.hasOpening,
      onPressed: callbacks.onDeselect,
    ),
    RoomEditorToolAction(
      id: 'split',
      icon: Icons.content_cut,
      label: 'Split',
      helpText:
          'Split the selected wall into two connected wall segments at its '
          'midpoint.',
      enabled: state.hasLine,
      onPressed: callbacks.onSplit,
    ),
    RoomEditorToolAction(
      id: 'door',
      icon: Icons.door_front_door_outlined,
      label: 'Door',
      helpText: 'Add a door opening to the selected wall.',
      enabled: state.hasLine,
      onPressed: callbacks.onAddDoor,
    ),
    RoomEditorToolAction(
      id: 'window',
      icon: Icons.web_asset_outlined,
      label: 'Window',
      helpText: 'Add a window opening to the selected wall.',
      enabled: state.hasLine,
      onPressed: callbacks.onAddWindow,
    ),
    RoomEditorToolAction(
      id: 'edit-opening',
      icon: state.isSelectedOpeningDoor
          ? Icons.door_front_door_outlined
          : Icons.web_asset_outlined,
      label: state.hasOpening ? 'Edit Opening' : 'Opening',
      helpText: 'Edit the currently selected door or window opening.',
      enabled: state.hasOpening,
      selected: state.hasOpening,
      onPressed: callbacks.onEditOpening,
    ),
    RoomEditorToolAction(
      id: 'delete-opening',
      icon: Icons.delete_outline,
      label: 'Delete Opening',
      helpText: 'Remove the currently selected door or window opening.',
      enabled: state.hasOpening,
      onPressed: callbacks.onDeleteOpening,
    ),
    RoomEditorToolAction(
      id: 'toggle-line-plaster',
      icon: state.isSelectedLinePlaster
          ? Icons.layers_clear_outlined
          : Icons.layers_outlined,
      label: state.isSelectedLinePlaster ? 'Exclude' : 'Include',
      helpText:
          'Include or exclude the selected wall from plasterboard layout '
          'calculation.',
      enabled: state.hasLine,
      onPressed: callbacks.onToggleLinePlaster,
    ),
  ];

  final constraintButtons = <RoomEditorToolAction>[
    RoomEditorToolAction(
      id: 'length',
      icon: Icons.straighten,
      label: 'Length',
      helpText:
          'Set or edit a fixed length constraint on the selected wall. '
          'Delete the constraint from its canvas icon.',
      enabled: state.hasLine,
      onPressed: callbacks.onSetLineLength,
    ),
    RoomEditorToolAction(
      id: 'horizontal',
      icon: Icons.horizontal_rule,
      label: 'Horizontal',
      helpText:
          'Set a horizontal constraint on the selected wall. Delete the '
          'constraint from its canvas icon.',
      enabled: state.hasLine,
      onPressed: callbacks.onSetHorizontal,
    ),
    RoomEditorToolAction(
      id: 'vertical',
      iconWidget: const RotatedBox(
        quarterTurns: 1,
        child: Icon(Icons.horizontal_rule),
      ),
      label: 'Vertical',
      helpText:
          'Set a vertical constraint on the selected wall. Delete the '
          'constraint from its canvas icon.',
      enabled: state.hasLine,
      onPressed: callbacks.onSetVertical,
    ),
    RoomEditorToolAction(
      id: 'joint',
      icon: Icons.polyline,
      label: 'Joint',
      helpText:
          'Open joint actions for the selected corner, including joining '
          'lines and managing joint-angle constraints.',
      enabled: state.hasIntersection,
      onPressed: callbacks.onJointAction,
    ),
    RoomEditorToolAction(
      id: 'angle',
      icon: Icons.architecture,
      label: 'Angle',
      helpText:
          'Set or edit a fixed angle constraint on the selected joint. '
          'Delete the constraint from its canvas icon.',
      enabled: state.hasIntersection,
      onPressed: callbacks.onSetAngle,
    ),
    RoomEditorToolAction(
      id: 'show-all-constraints',
      icon: state.showAllConstraints
          ? Icons.visibility
          : Icons.visibility_outlined,
      label: 'All Constraints',
      helpText:
          'Show or hide every constraint annotation. When off, only the '
          "selected element's constraints are shown.",
      selected: state.showAllConstraints,
      onPressed: callbacks.onToggleShowAllConstraints,
    ),
  ];

  if (constraintsOnly) {
    return constraintButtons;
  }
  if (excludeConstraints) {
    return primaryButtons;
  }
  return [...primaryButtons, ...constraintButtons];
}
