/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../widgets/hmb_button.dart';

typedef OnConfirmed = Future<void> Function();

Future<void> askUserToContinue({
  required BuildContext context,
  required OnConfirmed onConfirmed,
  required String title,
  required String message,
  String noLabel = 'No',
  String yesLabel = 'Yes',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        HMBButton(
          label: noLabel,
          hint: "Don't continue with the action",
          onPressed: () => Navigator.of(context).pop(false),
        ),
        HMBButton(
          label: yesLabel,
          hint: 'Continue with the action',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  if (confirmed ?? false) {
    await onConfirmed();
  }
}
