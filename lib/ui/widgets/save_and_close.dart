/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:flutter/material.dart';

import '../../util/dart/types.dart';
import 'hmb_button.dart';
import 'layout/hmb_spacer.dart';

class SaveAndClose extends StatelessWidget {
  final Future<void> Function({required bool close}) onSave;
  final AsyncVoidCallback onCancel;
  final bool showSaveOnly;

  /// Retained for older call sites. Save now always closes when validation
  /// passes; child add flows use the edit screen's ensure-saved hook.
  const SaveAndClose({
    required this.onSave,
    required this.showSaveOnly,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        HMBButton(
          label: 'Save',
          hint: 'Save your changes',
          onPressed: () => unawaited(onSave(close: true)),
        ),
        const HMBSpacer(width: true),
        HMBButton(
          onPressed: onCancel,
          label: 'Cancel',
          hint: "Dont' save any changes",
        ),
      ],
    ),
  );
}
