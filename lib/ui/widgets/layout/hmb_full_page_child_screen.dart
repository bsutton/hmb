import 'package:material_ui/material_ui.dart';

import '../text/text.g.dart';

class HMBFullPageChildScreen extends StatelessWidget {
  final Widget child;
  final String title;
  final bool subdued;
  final double? maxContentWidth;

  const HMBFullPageChildScreen({
    required this.child,
    required this.title,
    this.subdued = false,
    this.maxContentWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: subdued ? Text(title) : HMBTextHeadline(title),
      backgroundColor: subdued
          ? Theme.of(context).colorScheme.surface
          : Colors.purple,
    ),
    body: maxContentWidth == null
        ? child
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth!),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
  );
}
