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
  final String saveLabel;

  /// The [showSaveOnly] argument indicates that the first save should keep
  /// the editor open so child records can be added.
  const SaveAndClose({
    required this.onSave,
    required this.showSaveOnly,
    required this.onCancel,
    this.saveLabel = 'Save',
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        HMBButton(
          label: saveLabel,
          hint: showSaveOnly
              ? 'Save your changes so child records can be added'
              : 'Save your changes',
          onPressed: () => unawaited(onSave(close: !showSaveOnly)),
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
