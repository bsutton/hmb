import 'package:flutter/widgets.dart';

import 'layout.g.dart';

class HMBRow extends StatelessWidget {
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  final List<Widget> children;

  const HMBRow({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  List<Widget> withSpacing(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        out.add(const HMBSpacer(width: true));
      }
      out.add(children[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    children: withSpacing(children),
  );
}
