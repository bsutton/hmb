import 'package:flutter/material.dart';

import 'editor_toolbar_models.dart';

class RoomEditorToolbar extends StatelessWidget {
  final List<RoomEditorToolAction> actions;
  final bool vertical;
  final bool wrap;

  const RoomEditorToolbar({
    required this.actions,
    super.key,
    this.vertical = false,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 420;

    if (vertical) {
      return SizedBox(
        width: compact ? 104 : 116,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: compact ? 4 : 6,
          crossAxisSpacing: compact ? 4 : 6,
          children: [
            for (final action in actions)
              _ToolbarButton(action: action, compact: compact),
          ],
        ),
      );
    }

    if (wrap) {
      return Wrap(
        spacing: compact ? 4 : 6,
        runSpacing: compact ? 4 : 6,
        children: [
          for (final action in actions)
            _ToolbarButton(action: action, compact: compact),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final action in actions) ...[
            _ToolbarButton(action: action, compact: compact),
            SizedBox(width: compact ? 4 : 6),
          ],
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final RoomEditorToolAction action;
  final bool compact;

  const _ToolbarButton({required this.action, required this.compact});

  Future<void> _showHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.label),
        content: Text(action.helpText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: action.helpText,
    triggerMode: TooltipTriggerMode.longPress,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showHelp(context),
      child: IconButton.filledTonal(
        constraints: BoxConstraints.tightFor(
          width: compact ? 44 : 48,
          height: compact ? 44 : 48,
        ),
        padding: EdgeInsets.zero,
        iconSize: compact ? 20 : 24,
        visualDensity: compact
            ? const VisualDensity(horizontal: -2, vertical: -2)
            : VisualDensity.standard,
        isSelected: action.selected,
        onPressed: action.enabled ? action.onPressed : null,
        icon: action.iconWidget ?? Icon(action.icon),
      ),
    ),
  );
}
