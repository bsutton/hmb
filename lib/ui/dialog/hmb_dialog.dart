import 'package:flutter/material.dart';

class HMBDialog extends StatelessWidget {
  const HMBDialog({
    required this.title,
    required this.content,
    super.key,
    this.actions,
    this.insetPadding = const EdgeInsets.all(8), // Default padding to 0
    this.titlePadding = const EdgeInsets.all(8),
    this.contentPadding = const EdgeInsets.all(8),
  });

  final Widget title;
  final Widget content;
  final List<Widget>? actions;
  final EdgeInsets insetPadding;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: insetPadding,
    // Controls the padding outside the dialog
    child: Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AlertDialog(
              titlePadding: titlePadding,
              contentPadding: contentPadding,
              insetPadding: EdgeInsets.zero,
              title: title,
              content: content,
              actions: actions,
            ),
          ],
        ),
      ),
    ),
  );
}
