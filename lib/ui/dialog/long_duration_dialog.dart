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
            hint: 'Edit the duration',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButton(
            label: 'Continue',
            hint: 'Save the long duration',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ??
    false;
