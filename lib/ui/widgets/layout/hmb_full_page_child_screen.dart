import 'package:flutter/material.dart';

import '../text/text.g.dart';

class HMBFullPageChildScreen extends StatelessWidget {
  final Widget child;
  final String title;

  const HMBFullPageChildScreen({
    required this.child,
    required this.title,
    super.key,
  });


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
