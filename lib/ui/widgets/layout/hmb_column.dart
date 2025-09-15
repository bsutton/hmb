import 'package:flutter/widgets.dart';

import 'layout.g.dart';

class HMBColumn extends StatelessWidget {
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  final List<Widget> children;

  const HMBColumn({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });


  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: crossAxisAlignment,
    children: _withSpacing(children),
  );


  List<Widget> _withSpacing(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        out.add(const HMBSpacer(height: true));
      }
      out.add(children[i]);
    }
    return out;
  }
}
