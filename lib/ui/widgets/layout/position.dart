import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';

enum TopOrTailPlacement { top, bottom }

///
/// Provide a simle method of positioning a widget
/// which is a child of a Stack at either
/// the top or bottom of the page.
class TopOrTail extends StatelessWidget {
  const TopOrTail({required this.placement, required this.child, super.key});
  final Widget child;
  final TopOrTailPlacement placement;

  @override
  Widget build(BuildContext context) {
    if (placement == TopOrTailPlacement.bottom) {
      return Positioned(bottom: 5, right: HMBTheme.padding, child: child);
    } else {
      return Positioned(top: 5, right: HMBTheme.padding, child: child);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TopOrTailPlacement>('placement', placement));
  }
}
