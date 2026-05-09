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
import 'package:money2/money2.dart';

import '../widgets/fields/fields.g.dart';
import '../widgets/hmb_button.dart';

class InvoiceWriteOffRequest {
  final String reason;
  final bool smallBalanceOnly;

  const InvoiceWriteOffRequest({
    required this.reason,
    required this.smallBalanceOnly,
  });
}

Future<InvoiceWriteOffRequest?> showWriteOffInvoiceBalanceDialog({
  required BuildContext context,
  required Money balance,
  required bool smallBalance,
}) {
  final reasonController = TextEditingController(
    text: smallBalance ? 'Small balance write-off' : '',
  );
  final formKey = GlobalKey<FormState>();

  return showDialog<InvoiceWriteOffRequest>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(smallBalance ? 'Write Off Small Balance' : 'Write Off'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance: $balance'),
            HMBTextField(
              controller: reasonController,
              labelText: 'Reason',
              fieldKey: const ValueKey('write_off_reason_field'),
              required: true,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: 'Close without writing off the invoice balance',
          onPressed: () => Navigator.of(context).pop(),
        ),
        HMBButton(
          label: 'Write Off',
          hint: 'Write off this invoice balance',
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              InvoiceWriteOffRequest(
                reason: reasonController.text.trim(),
                smallBalanceOnly: smallBalance,
              ),
            );
          },
        ),
      ],
    ),
  );
}
