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
    if (vertical) {
      return SizedBox(
        width: 116,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final action in actions) _ToolbarButton(action: action),
          ],
        ),
      );
    }

    if (wrap) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final action in actions) _ToolbarButton(action: action),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final action in actions) ...[
            _ToolbarButton(action: action),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final RoomEditorToolAction action;

  const _ToolbarButton({required this.action});

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
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => action.enabled ? _showHelp(context) : null,
    child: IconButton.filledTonal(
      isSelected: action.selected,
      onPressed: action.enabled ? action.onPressed : null,
      icon: action.iconWidget ?? Icon(action.icon),
    ),
  );
}
