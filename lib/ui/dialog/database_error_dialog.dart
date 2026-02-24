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
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../widgets/hmb_button.dart';
import '../widgets/layout/layout.g.dart';
import 'hmb_dialog.dart';

class DatabaseErrorDialog extends StatelessWidget {
  final String error;

  const DatabaseErrorDialog({required this.error, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HMBDialog(
      title: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Database Error',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              HMBButtonPrimary(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: error));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error copied to clipboard'),
                      ),
                    );
                  }
                },
                label: 'Copy Error',
                hint: 'Copy the error to the clipboard',
              ),
              HMBButtonSecondary(
                onPressed: () {
                  context.go('/home/settings/backup/google/restore');
                },
                label: 'Restore Database',
                hint: 'Restore the datbase from a Google Drive backup',
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: SelectableText(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
