import 'package:flutter/material.dart';

import 'hmb_button.dart';
import 'layout/hmb_spacer.dart';

class SaveAndClose extends StatelessWidget {
  const SaveAndClose({required this.onSave, required this.onCancel, super.key});

  final Future<void> Function({required bool close}) onSave;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            HMBButton(
              onPressed: () async => onSave(close: false),
              label: 'Save',
            ),
            const HMBSpacer(width: true),
            HMBButton(
              label: 'Save & Close',
              onPressed: () async => onSave(close: true),
            ),
            const HMBSpacer(width: true),
            HMBButton(
              onPressed: onCancel,
              label: 'Cancel',
            ),
          ],
        ),
      );
}
