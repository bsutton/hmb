import 'dart:async';

import 'package:flutter/material.dart';

import 'hmb_button.dart';
import 'layout/hmb_spacer.dart';

class SaveAndClose extends StatelessWidget {
  /// The [showSaveOnly] argument controls whether the 'Save' button
  /// will be displayed. We normally only display the save button
  /// during the insert phase of a CRUD.
  const SaveAndClose({
    required this.onSave,
    required this.showSaveOnly,
    required this.onCancel,
    super.key,
  });

  final Future<void> Function({required bool close}) onSave;
  final Future<void> Function() onCancel;
  final bool showSaveOnly;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showSaveOnly)
          HMBButton(onPressed: () => unawaited(onSave(close: false)), label: 'Save'),
        const HMBSpacer(width: true),
        HMBButton(label: 'Save & Close', onPressed: () => unawaited(onSave(close: true))),
        const HMBSpacer(width: true),
        HMBButton(onPressed: onCancel, label: 'Cancel'),
      ],
    ),
  );
}
