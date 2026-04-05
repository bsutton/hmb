import 'package:flutter/material.dart';

class RoomEditorShell extends StatelessWidget {
  final Widget primaryTools;
  final Widget canvas;
  final Widget? constraintTools;
  final bool landscape;
  final bool editorOnly;
  final double spacing;

  const RoomEditorShell({
    super.key,
    required this.primaryTools,
    required this.canvas,
    this.constraintTools,
    this.landscape = false,
    this.editorOnly = false,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          primaryTools,
          SizedBox(width: spacing),
          Expanded(child: canvas),
          if (constraintTools != null) ...[
            SizedBox(width: spacing),
            constraintTools!,
          ],
        ],
      );
    }

    return Column(
      children: [
        primaryTools,
        SizedBox(height: editorOnly ? 8 : spacing),
        if (editorOnly) Expanded(child: canvas) else canvas,
      ],
    );
  }
}
