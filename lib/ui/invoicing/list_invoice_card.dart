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

import '../../dao/debtor_ledger_service.dart';
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
      if (_showBalance) Text('Balance: ${invoiceDetails.ledger.balance}'),
      if (Strings.isNotBlank(invoiceDetails.invoice.voidDescription))
        Text(
          'Void: ${invoiceDetails.invoice.voidDescription}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
              tone: _outstandingTone,
              icon: Icons.warning_amber_rounded,
            ),
        ],
      ),
    ],
  );

  int? get _overdueDays {
    final invoice = invoiceDetails.invoice;
    if (!invoiceDetails.ledger.isOutstanding ||
        invoice.isExternallyDeletedOrVoided) {
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
        return _localStatusLabel;
    }
  }

  HMBChipTone get _statusTone {
    switch (invoiceDetails.invoice.externalSyncStatus) {
      case InvoiceExternalSyncStatus.deleted:
      case InvoiceExternalSyncStatus.voided:
        return HMBChipTone.danger;
      case InvoiceExternalSyncStatus.none:
      case InvoiceExternalSyncStatus.linked:
        return _localStatusTone;
    }
  }

  HMBChipTone get _outstandingTone {
    final overdueDays = _overdueDays;
    if (overdueDays == null) {
      return HMBChipTone.neutral;
    }
    return overdueDays >= 7 ? HMBChipTone.danger : HMBChipTone.warning;
  }

  IconData get _statusIcon {
    switch (invoiceDetails.invoice.externalSyncStatus) {
      case InvoiceExternalSyncStatus.deleted:
        return Icons.delete_forever;
      case InvoiceExternalSyncStatus.voided:
        return Icons.cancel;
      case InvoiceExternalSyncStatus.none:
      case InvoiceExternalSyncStatus.linked:
        return _localStatusIcon;
    }
  }

  bool get _showBalance =>
      invoiceDetails.ledger.paid.isNonZero ||
      invoiceDetails.ledger.credited.isNonZero ||
      invoiceDetails.ledger.adjusted.isNonZero ||
      invoiceDetails.ledger.balance != invoiceDetails.invoice.totalAmount;

  String get _localStatusLabel {
    final invoice = invoiceDetails.invoice;
    final ledger = invoiceDetails.ledger;
    switch (ledger.status) {
      case DebtorInvoiceStatus.paid:
        return invoice.paidDate == null
            ? 'Paid'
            : 'Paid ${formatDate(invoice.paidDate!)}';
      case DebtorInvoiceStatus.writtenOff:
        return 'Written off';
      case DebtorInvoiceStatus.partPaid:
        return 'Part paid, balance ${ledger.balance}';
      case DebtorInvoiceStatus.credited:
        return 'Credited, balance ${ledger.balance}';
      case DebtorInvoiceStatus.overpaid:
        return 'Overpaid';
      case DebtorInvoiceStatus.voided:
        return 'Voided';
      case DebtorInvoiceStatus.draft:
      case DebtorInvoiceStatus.sent:
        return 'Outstanding due ${formatLocalDate(invoice.dueDate)}';
    }
  }

  HMBChipTone get _localStatusTone {
    switch (invoiceDetails.ledger.status) {
      case DebtorInvoiceStatus.paid:
      case DebtorInvoiceStatus.writtenOff:
        return HMBChipTone.accent;
      case DebtorInvoiceStatus.partPaid:
      case DebtorInvoiceStatus.credited:
      case DebtorInvoiceStatus.overpaid:
        return HMBChipTone.warning;
      case DebtorInvoiceStatus.voided:
        return HMBChipTone.danger;
      case DebtorInvoiceStatus.draft:
      case DebtorInvoiceStatus.sent:
        return _outstandingTone;
    }
  }

  IconData get _localStatusIcon {
    switch (invoiceDetails.ledger.status) {
      case DebtorInvoiceStatus.paid:
        return Icons.check_circle;
      case DebtorInvoiceStatus.writtenOff:
        return Icons.rule;
      case DebtorInvoiceStatus.partPaid:
        return Icons.payments;
      case DebtorInvoiceStatus.credited:
        return Icons.assignment_return;
      case DebtorInvoiceStatus.overpaid:
        return Icons.add_card;
      case DebtorInvoiceStatus.voided:
        return Icons.cancel;
      case DebtorInvoiceStatus.draft:
      case DebtorInvoiceStatus.sent:
        return Icons.pending_actions;
    }
  }

  Widget _buildXeroChip() {
    final invoice = invoiceDetails.invoice;
    if (invoice.isManagedLocally) {
      return const HMBChip(
        label: 'Managed locally',
        tone: HMBChipTone.accent,
        icon: Icons.home_repair_service,
      );
    }

    final invoiceNum = invoice.invoiceNum;
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
