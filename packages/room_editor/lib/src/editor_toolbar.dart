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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final windowWidth = MediaQuery.sizeOf(context).width;
      final baseTier = switch (windowWidth) {
        < 560 => _ToolbarDensity.tight,
        < 760 => _ToolbarDensity.compact,
        _ => _ToolbarDensity.normal,
      };
      final tier = vertical ? baseTier.compacted : baseTier;

      if (vertical) {
        return SizedBox(
          width: tier.columnWidth,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: tier.spacing,
            crossAxisSpacing: tier.spacing,
            children: [
              for (final action in actions)
                _ToolbarButton(action: action, tier: tier),
            ],
          ),
        );
      }

      if (wrap) {
        return Wrap(
          spacing: tier.spacing,
          runSpacing: tier.spacing,
          children: [
            for (final action in actions)
              _ToolbarButton(action: action, tier: tier),
          ],
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final action in actions) ...[
              _ToolbarButton(action: action, tier: tier),
              SizedBox(width: tier.spacing),
            ],
          ],
        ),
      );
    },
  );
}

enum _ToolbarDensity { normal, compact, tight }

extension on _ToolbarDensity {
  _ToolbarDensity get compacted => switch (this) {
    _ToolbarDensity.normal => _ToolbarDensity.compact,
    _ToolbarDensity.compact => _ToolbarDensity.tight,
    _ToolbarDensity.tight => _ToolbarDensity.tight,
  };

  double get columnWidth => switch (this) {
    _ToolbarDensity.normal => 116,
    _ToolbarDensity.compact => 96,
    _ToolbarDensity.tight => 88,
  };

  double get spacing => switch (this) {
    _ToolbarDensity.normal => 6,
    _ToolbarDensity.compact => 4,
    _ToolbarDensity.tight => 3,
  };

  double get buttonSize => switch (this) {
    _ToolbarDensity.normal => 48,
    _ToolbarDensity.compact => 40,
    _ToolbarDensity.tight => 36,
  };

  double get iconSize => switch (this) {
    _ToolbarDensity.normal => 24,
    _ToolbarDensity.compact => 20,
    _ToolbarDensity.tight => 18,
  };

  VisualDensity get visualDensity => switch (this) {
    _ToolbarDensity.normal => VisualDensity.standard,
    _ToolbarDensity.compact => const VisualDensity(
      horizontal: -1,
      vertical: -1,
    ),
    _ToolbarDensity.tight => const VisualDensity(horizontal: -2, vertical: -2),
  };
}

class _ToolbarButton extends StatelessWidget {
  final RoomEditorToolAction action;
  final _ToolbarDensity tier;

  const _ToolbarButton({required this.action, required this.tier});

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
          width: tier.buttonSize,
          height: tier.buttonSize,
        ),
        padding: EdgeInsets.zero,
        iconSize: tier.iconSize,
        visualDensity: tier.visualDensity,
        isSelected: action.selected,
        onPressed: action.enabled ? action.onPressed : null,
        icon: action.iconWidget ?? Icon(action.icon),
      ),
    ),
  );
}
