import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'room_canvas_models.dart';

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
  final RoomEditorGridControlsMode gridControlsMode;
  final bool snapToGrid;
  final bool showGrid;
  final int selectedLineCount;
  final int selectedIntersectionCount;
  final bool hasOpening;
  final bool canSetLength;
  final bool canSplit;
  final bool canJoin;
  final bool hasLineLengthConstraint;
  final bool hasHorizontalConstraint;
  final bool hasVerticalConstraint;
  final bool hasAngleConstraint;
  final bool canSetAngle;
  final bool canSetRightAngle;
  final bool canSetParallel;
  final bool showAllConstraints;
  final bool isSelectedOpeningDoor;
  final List<RoomEditorToolAction> customActions;

  const RoomEditorToolbarState({
    required this.gridControlsMode,
    required this.snapToGrid,
    required this.showGrid,
    required this.selectedLineCount,
    required this.selectedIntersectionCount,
    required this.hasOpening,
    required this.canSetLength,
    required this.canSplit,
    required this.canJoin,
    required this.hasLineLengthConstraint,
    required this.hasHorizontalConstraint,
    required this.hasVerticalConstraint,
    required this.hasAngleConstraint,
    required this.canSetAngle,
    required this.canSetRightAngle,
    required this.canSetParallel,
    required this.showAllConstraints,
    required this.isSelectedOpeningDoor,
    this.customActions = const [],
  });
}

class RoomEditorToolbarCallbacks {
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
  final VoidCallback? onSetLineLength;
  final VoidCallback? onSetHorizontal;
  final VoidCallback? onSetVertical;
  final VoidCallback? onJointAction;
  final VoidCallback? onSetAngle;
  final VoidCallback? onSetRightAngle;
  final VoidCallback? onSetParallel;
  final VoidCallback onToggleShowAllConstraints;

  const RoomEditorToolbarCallbacks({
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
    required this.onSetLineLength,
    required this.onSetHorizontal,
    required this.onSetVertical,
    required this.onJointAction,
    required this.onSetAngle,
    required this.onSetRightAngle,
    required this.onSetParallel,
    required this.onToggleShowAllConstraints,
  });
}

class _WindowToolbarIcon extends StatelessWidget {
  const _WindowToolbarIcon();

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? 24.0;
    final color = iconTheme.color ?? Colors.white;
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/icons/window_toolbar.svg',
        package: 'room_editor',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

List<RoomEditorToolAction> buildRoomEditorToolbarActions({
  required RoomEditorToolbarState state,
  required RoomEditorToolbarCallbacks callbacks,
  bool constraintsOnly = false,
  bool excludeConstraints = false,
}) {
  final primaryButtons = <RoomEditorToolAction>[
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
          'Reset the drawing zoom and pan so the current room fits in the '
          'view.',
      onPressed: callbacks.onFit,
    ),
    if (state.gridControlsMode != RoomEditorGridControlsMode.none)
      RoomEditorToolAction(
        id: 'toggle-grid',
        icon: state.showGrid ? Icons.border_all : Icons.border_clear,
        label: state.showGrid ? 'Grid On' : 'Grid Off',
        helpText: 'Show or hide the background drawing grid.',
        selected: state.showGrid,
        onPressed: callbacks.onToggleShowGrid,
      ),
    if (state.gridControlsMode == RoomEditorGridControlsMode.gridAndSnap)
      RoomEditorToolAction(
        id: 'toggle-snap',
        icon: state.snapToGrid ? Icons.grid_on : Icons.grid_off,
        label: state.snapToGrid ? 'Snap On' : 'Snap Off',
        helpText:
            'Turn grid snapping on or off when moving points and openings.',
        selected: state.snapToGrid,
        enabled: state.showGrid,
        onPressed: callbacks.onToggleSnapToGrid,
      ),
    RoomEditorToolAction(
      id: 'deselect',
      icon: Icons.deselect,
      label: 'Deselect All',
      helpText: 'Clear all selections.',
      enabled:
          state.selectedLineCount > 0 ||
          state.selectedIntersectionCount > 0 ||
          state.hasOpening,
      onPressed: callbacks.onDeselect,
    ),
    RoomEditorToolAction(
      id: 'topology',
      icon: state.canJoin ? Icons.join_inner : Icons.content_cut,
      label: state.canJoin ? 'Join' : 'Split',
      helpText: state.canJoin
          ? 'Remove the selected corner and join the adjacent walls.'
          : 'Split the selected wall into two connected wall segments at its '
                'midpoint.',
      enabled: state.canJoin || state.canSplit,
      onPressed: state.canJoin ? callbacks.onJointAction : callbacks.onSplit,
    ),
    RoomEditorToolAction(
      id: 'door',
      icon: Icons.door_front_door_outlined,
      label: 'Door',
      helpText: 'Add a door opening to the selected wall.',
      enabled: state.selectedLineCount == 1,
      onPressed: callbacks.onAddDoor,
    ),
    RoomEditorToolAction(
      id: 'window',
      iconWidget: const _WindowToolbarIcon(),
      label: 'Window',
      helpText: 'Add a window opening to the selected wall.',
      enabled: state.selectedLineCount == 1,
      onPressed: callbacks.onAddWindow,
    ),
    RoomEditorToolAction(
      id: 'edit-opening',
      icon: state.isSelectedOpeningDoor ? Icons.door_front_door_outlined : null,
      iconWidget: state.isSelectedOpeningDoor
          ? null
          : const _WindowToolbarIcon(),
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
  ];

  final constraintButtons = <RoomEditorToolAction>[
    RoomEditorToolAction(
      id: 'length',
      icon: Icons.straighten,
      label: 'Length',
      helpText:
          'Set or edit a fixed length on the selected wall or opening '
          'dimension.',
      enabled: state.canSetLength,
      onPressed: callbacks.onSetLineLength,
    ),
    RoomEditorToolAction(
      id: 'horizontal',
      icon: Icons.horizontal_rule,
      label: 'Horizontal',
      helpText: 'Set a horizontal constraint on the selected wall.',
      enabled: state.selectedLineCount == 1,
      onPressed: callbacks.onSetHorizontal,
    ),
    RoomEditorToolAction(
      id: 'vertical',
      iconWidget: const RotatedBox(
        quarterTurns: 1,
        child: Icon(Icons.horizontal_rule),
      ),
      label: 'Vertical',
      helpText: 'Set a vertical constraint on the selected wall.',
      enabled: state.selectedLineCount == 1,
      onPressed: callbacks.onSetVertical,
    ),
    RoomEditorToolAction(
      id: 'angle',
      icon: Icons.architecture,
      label: 'Angle',
      helpText:
          'Set or edit a fixed angle constraint on the selected joint or the '
          'shared corner of two adjacent selected walls.',
      enabled: state.canSetAngle,
      onPressed: callbacks.onSetAngle,
    ),
    RoomEditorToolAction(
      id: 'right-angle',
      icon: Icons.square_foot,
      label: 'Right Angle',
      helpText:
          'Set a 90 degree angle constraint on the selected joint or the '
          'shared corner of two adjacent selected walls.',
      enabled: state.canSetRightAngle,
      onPressed: callbacks.onSetRightAngle,
    ),
    RoomEditorToolAction(
      id: 'parallel',
      iconWidget: const _ParallelConstraintToolbarIcon(),
      label: 'Parallel',
      helpText:
          'Set a parallel constraint between two selected non-adjacent walls.',
      enabled: state.canSetParallel,
      onPressed: callbacks.onSetParallel,
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
  final combinedPrimary = [...primaryButtons, ...state.customActions];
  if (excludeConstraints) {
    return combinedPrimary;
  }
  return [...combinedPrimary, ...constraintButtons];
}

class _ParallelConstraintToolbarIcon extends StatelessWidget {
  const _ParallelConstraintToolbarIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _ParallelConstraintToolbarPainter(color)),
    );
  }
}

class _ParallelConstraintToolbarPainter extends CustomPainter {
  final Color color;

  const _ParallelConstraintToolbarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final firstStart = Offset(size.width * 0.18, size.height * 0.65);
    final firstEnd = Offset(size.width * 0.82, size.height * 0.42);
    const separation = Offset(0, -5);
    canvas
      ..drawLine(firstStart, firstEnd, paint)
      ..drawLine(firstStart + separation, firstEnd + separation, paint);
  }

  @override
  bool shouldRepaint(covariant _ParallelConstraintToolbarPainter oldDelegate) =>
      oldDelegate.color != color;
}
