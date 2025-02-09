import 'package:flutter/material.dart';

class HMBLinkInternal extends StatelessWidget {
  const HMBLinkInternal({
    required this.label,
    required this.navigateTo,
    super.key,
  });

  final String label;
  final Future<Widget> Function() navigateTo;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final widget = await navigateTo();
          if (context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => widget),
            );
          }
        },
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.green, decoration: TextDecoration.underline),
        ),
      );
}
