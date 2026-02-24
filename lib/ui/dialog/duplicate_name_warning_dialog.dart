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

import 'package:flutter/material.dart';

import '../widgets/hmb_button.dart';

Future<bool> showDuplicateNameWarningDialog({
  required BuildContext context,
  required String entityName,
  required String name,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duplicate $entityName'),
        content: Text(
          'A $entityName named "$name" already exists.\n'
          'Do you want to continue anyway?',
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            hint: "Don't save this $entityName",
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HMBButton(
            label: 'Continue',
            hint: 'Save this $entityName anyway',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ??
    false;
