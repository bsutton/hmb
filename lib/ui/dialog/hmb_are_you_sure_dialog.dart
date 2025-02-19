import 'package:flutter/material.dart';

import '../widgets/hmb_button.dart';

typedef OnConfirmed = Future<void> Function();

Future<void> areYouSure({
  required BuildContext context,
  required OnConfirmed onConfirmed,
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            HMBButton(
              label: 'No',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            HMBButton(
              label: 'Yes',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
  );

  if (confirmed ?? false) {
    await onConfirmed();
  }
}
