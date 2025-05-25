import 'package:flutter/material.dart';

import '../widgets/widgets.g.dart';
import 'dialog.g.dart';

Future<bool> showLongDurationDialog(
  BuildContext context,
  Duration duration,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => HMBDialog(
        title: const Text('Long Duration Warning'),
        content: Text(
          '''The time entry duration is ${duration.inHours} hours. Do you want to continue?''',
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButton(
            label: 'Continue',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ??
    false;
