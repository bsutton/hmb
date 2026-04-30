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
import 'package:strings/strings.dart';

import '../../api/external_accounting.dart';
import '../../api/xero/xero_api.dart';
import '../../dao/dao_invoice.dart';
import '../../entity/invoice.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';

Future<bool> promptAndVoidInvoice({
  required BuildContext context,
  required Invoice invoice,
}) async {
  if (invoice.paid) {
    HMBToast.error('An invoice with a payment may not be voided.');
    return false;
  }
  if (!invoice.sent) {
    HMBToast.error('Only sent invoices need to be voided.');
    return false;
  }
  if (invoice.isExternallyDeletedOrVoided) {
    HMBToast.error('This invoice has already been voided.');
    return false;
  }

  final description = await _promptForVoidDescription(context, invoice);
  if (description == null) {
    return false;
  }

  try {
    if (await ExternalAccounting().isEnabled()) {
      if (Strings.isNotBlank(invoice.invoiceNum)) {
        final xeroApi = XeroApi();
        await xeroApi.login();
        await BlockingUI().runAndWait(() async {
          await xeroApi.voidInvoice(invoice);
        }, label: 'Voiding Invoice');
      }
    }
    await DaoInvoice().voidInvoice(
      invoiceId: invoice.id,
      description: description,
    );
    HMBToast.info('Invoice ${invoice.bestNumber} voided');
    return true;
  } catch (e) {
    HMBToast.error('Failed to void invoice: $e', acknowledgmentRequired: true);
    return false;
  }
}

Future<String?> _promptForVoidDescription(
  BuildContext context,
  Invoice invoice,
) async {
  final descriptionController = TextEditingController();
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Void Invoice ${invoice.bestNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This sent invoice cannot be deleted. Enter the description '
              'that should be kept with the voided invoice.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Void description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            hint: 'Do not void this invoice',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HMBButton(
            label: 'Void',
            hint: 'Void this invoice',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return null;
    }

    final description = descriptionController.text.trim();
    if (Strings.isBlank(description)) {
      HMBToast.error('A void description is required.');
      return null;
    }
    return description;
  } finally {
    descriptionController.dispose();
  }
}
