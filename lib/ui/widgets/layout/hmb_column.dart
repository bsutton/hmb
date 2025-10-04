import 'package:flutter/widgets.dart';

class HMBColumn extends StatelessWidget {
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final bool leadingSpace;
  final double spacing;

  final List<Widget> children;

  const HMBColumn({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.leadingSpace = false,
    super.key,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: crossAxisAlignment,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    children: _withSpacing(children),
  );

  List<Widget> _withSpacing(List<Widget> children) {
    final out = <Widget>[];
    if (leadingSpace) {
      out.add(SizedBox(height: spacing));
    }
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        out.add(SizedBox(height: spacing));
      }
      out.add(children[i]);
    }
    return out;
  }
}
