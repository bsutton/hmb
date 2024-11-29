import 'package:flutter/material.dart';

typedef OnConfirmed = Future<void> Function();

Future<void> areYouSure(
    {required BuildContext context,
    required OnConfirmed onConfirmed,
    required String title,
    required String message}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  if (confirmed ?? false) {
    await onConfirmed();
  }
}
