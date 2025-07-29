import 'package:flutter/material.dart';

import '../text/text.g.dart';

class HMBFullPageChildScreen extends StatelessWidget {
  const HMBFullPageChildScreen({
    required this.child,
    required this.title,
    super.key,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: HMBTextHeadline(title),
      backgroundColor: Colors.purple,
    ),
    body: child,
  );
}
