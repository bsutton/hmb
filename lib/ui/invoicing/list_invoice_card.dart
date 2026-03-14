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

import '../../util/dart/format.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';
import 'invoice_details.dart';

class ListInvoiceCard extends StatelessWidget {
  final InvoiceDetails invoiceDetails;

  final bool showJobDetails;

  const ListInvoiceCard({
    required this.invoiceDetails,
    required this.showJobDetails,
    super.key,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Issued: ${formatDate(invoiceDetails.invoice.createdDate)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(
        'Customer: ${invoiceDetails.customer?.name ?? 'N/A'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      if (showJobDetails)
        HMBLinkInternal(
          label:
              'Job: #${invoiceDetails.job.id} - ${invoiceDetails.job.summary}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          navigateTo: () async => FullPageListJobCard(invoiceDetails.job),
        ),
      Text('Total: ${invoiceDetails.invoice.totalAmount}'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildXeroChip(),
          if (invoiceDetails.invoice.sent)
            const HMBChip(
              label: 'Sent',
              tone: HMBChipTone.accent,
              icon: Icons.send,
            ),
          if (invoiceDetails.invoice.paid)
            HMBChip(
              label: invoiceDetails.invoice.paidDate == null
                  ? 'Paid'
                  : 'Paid ${formatDate(invoiceDetails.invoice.paidDate!)}',
              tone: HMBChipTone.accent,
              icon: Icons.check_circle,
            ),
        ],
      ),
    ],
  );

  Widget _buildXeroChip() {
    final invoiceNum = invoiceDetails.invoice.invoiceNum;
    if (invoiceNum == null || invoiceNum.isEmpty) {
      return const HMBChip(
        label: 'Not uploaded',
        tone: HMBChipTone.warning,
        icon: Icons.cloud_off,
      );
    }

    return HMBChip(label: 'Xero #$invoiceNum', icon: Icons.cloud_done);
  }
}
