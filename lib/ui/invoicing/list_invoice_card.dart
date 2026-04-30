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

import '../../entity/invoice.dart';
import '../../util/dart/format.dart';
import '../../util/dart/local_date.dart';
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
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _buildXeroChip(),
          if (invoiceDetails.invoice.sent)
            const HMBChip(
              label: 'Sent',
              tone: HMBChipTone.accent,
              icon: Icons.send,
            ),
          if (invoiceDetails.invoice.paymentSource ==
              InvoicePaymentSource.unknown)
            const HMBChip(
              label: 'Needs review',
              tone: HMBChipTone.warning,
              icon: Icons.help_outline,
            ),
          HMBChip(label: _statusLabel, tone: _statusTone, icon: _statusIcon),
          if (_overdueDays != null)
            HMBChip(
              label:
                  '${_overdueDays!} day${_overdueDays == 1 ? '' : 's'} overdue',
              tone: HMBChipTone.danger,
              icon: Icons.warning_amber_rounded,
            ),
        ],
      ),
    ],
  );

  int? get _overdueDays {
    final invoice = invoiceDetails.invoice;
    if (invoice.paid || invoice.isExternallyDeletedOrVoided) {
      return null;
    }
    final today = LocalDate.today();
    if (!invoice.dueDate.isBefore(today)) {
      return null;
    }
    return today.difference(invoice.dueDate).inDays;
  }

  String get _statusLabel {
    final invoice = invoiceDetails.invoice;
    switch (invoice.externalSyncStatus) {
      case InvoiceExternalSyncStatus.deleted:
        return 'Deleted in Xero';
      case InvoiceExternalSyncStatus.voided:
        return 'Voided in Xero';
      case InvoiceExternalSyncStatus.none:
      case InvoiceExternalSyncStatus.linked:
        if (invoice.paid) {
          return invoice.paidDate == null
              ? 'Paid'
              : 'Paid ${formatDate(invoice.paidDate!)}';
        }
        return 'Outstanding';
    }
  }

  HMBChipTone get _statusTone {
    switch (invoiceDetails.invoice.externalSyncStatus) {
      case InvoiceExternalSyncStatus.deleted:
      case InvoiceExternalSyncStatus.voided:
        return HMBChipTone.danger;
      case InvoiceExternalSyncStatus.none:
      case InvoiceExternalSyncStatus.linked:
        return invoiceDetails.invoice.paid
            ? HMBChipTone.accent
            : HMBChipTone.warning;
    }
  }

  IconData get _statusIcon {
    switch (invoiceDetails.invoice.externalSyncStatus) {
      case InvoiceExternalSyncStatus.deleted:
        return Icons.delete_forever;
      case InvoiceExternalSyncStatus.voided:
        return Icons.cancel;
      case InvoiceExternalSyncStatus.none:
      case InvoiceExternalSyncStatus.linked:
        return invoiceDetails.invoice.paid
            ? Icons.check_circle
            : Icons.pending_actions;
    }
  }

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
