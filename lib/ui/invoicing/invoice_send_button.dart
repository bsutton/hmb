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

import 'package:material_ui/material_ui.dart';
import 'package:strings/strings.dart';

import '../../api/external_accounting.dart';
import '../../dao/dao.g.dart';
import '../../dao/invoice_billing_contact.dart';
import '../../entity/contact.dart';
import '../../entity/invoice.dart';
import '../../entity/job.dart';
import '../../util/dart/exceptions.dart';
import '../../util/dart/format.dart';
import '../dialog/email_dialog_for_job.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/media/pdf_preview.dart';
import 'pdf/generate_invoice_pdf.dart';

class BuildSendButton extends StatelessWidget {
  final BuildContext context;
  final bool mounted;
  final Invoice invoice;
  final Future<void> Function()? onReturned;

  const BuildSendButton({
    required this.context,
    required this.mounted,
    required this.invoice,
    this.onReturned,
    super.key,
  });

  @override
  Widget build(BuildContext context) => HMBButton(
    label: invoice.sent ? 'View / resend' : 'Preview / send',
    hint: 'View and optionally email the Invoice',
    onPressed: () async {
      if (invoice.isExternallyDeletedOrVoided) {
        HMBToast.error('Voided or deleted invoices cannot be sent.');
        return;
      }
      var billBookingFee = true;
      var displayCosts = true;
      var displayGroupHeaders = true;
      var displayItems = true;
      var groupByTask = true; // Default to group by task

      final job = await DaoJob().getById(invoice.jobId);
      final site = job?.siteId == null
          ? null
          : await DaoSite().getById(job!.siteId);
      final primaryContact = await DaoContact().getPrimaryForJob(job!.id);
      final greetingContact = await invoiceGreetingContact(
        invoice: invoice,
        job: job,
        primaryContact: primaryContact,
      );

      if (!context.mounted) {
        return;
      }
      final result = await showInvoiceOptionsDialog(
        context: context,
        displayCosts: displayCosts,
        displayGroupHeaders: displayGroupHeaders,
        displayItems: displayItems,
        groupByTask: groupByTask,
        billBookingFee: billBookingFee,
      );

      if (result != null && mounted) {
        billBookingFee = result['billBookingFee'] ?? true;
        displayCosts = result['displayCosts'] ?? true;
        displayGroupHeaders = result['displayGroupHeaders'] ?? true;
        displayItems = result['displayItems'] ?? true;
        groupByTask = result['groupByTask'] ?? true;

        final filePath = await BlockingUI().runAndWait(
          label: 'Generating Invoice',
          () => generateInvoicePdf(
            invoice,
            displayCosts: displayCosts,
            displayGroupHeaders: displayGroupHeaders,
            displayItems: displayItems,
          ),
        );
        final system = await DaoSystem().get();

        final recipients = await DaoInvoice().getEmailsByInvoice(invoice);
        final preferredRecipient =
            Strings.isNotBlank(greetingContact?.bestEmail)
            ? greetingContact!.bestEmail
            : recipients.isEmpty
            ? ''
            : recipients.first;
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => PdfPreviewScreen(
                title: '''Invoice #${invoice.bestNumber} ${job.summary}''',
                filePath: filePath.path,
                preferredRecipient: preferredRecipient,
                emailSubject:
                    '''${system.businessName ?? 'Your'} Invoice #${invoice.bestNumber}''',
                emailBody: invoiceEmailBody(
                  invoice: invoice,
                  recipients: [?greetingContact],
                  siteAddress: site?.address,
                ),

                sendEmailDialog:
                    ({
                      preferredRecipient = '',
                      subject = '',
                      body = '',
                      attachmentPaths = const [],
                    }) => EmailDialogForJob(
                      job: job,
                      additionalContacts: [?greetingContact],
                      bodyForContacts: (contacts) => invoiceEmailBody(
                        invoice: invoice,
                        recipients: contacts,
                        siteAddress: site?.address,
                      ),
                      preferredRecipient: preferredRecipient,
                      subject: subject,
                      body: body,
                      attachmentPaths: attachmentPaths,
                    ),
                onSent: () => DaoInvoice().markSent(invoice),
                canEmail: () => checkInvoiceEmailAvailability(
                  invoice: invoice,
                  prepareBillingContact: () async {
                    await _prepareBillingContactForDelivery(invoice, job);
                  },
                ),
              ),
            ),
          );
          await onReturned?.call();
        }
      }
    },
  );

  Future<Map<String, bool>?> showInvoiceOptionsDialog({
    required BuildContext context,
    required bool displayCosts,
    required bool displayGroupHeaders,
    required bool displayItems,
    required bool groupByTask,
    required bool billBookingFee,
  }) => showDialog<Map<String, bool>>(
    context: context,
    builder: (context) {
      var tempDisplayCosts = displayCosts;
      var tempDisplayGroupHeaders = displayGroupHeaders;
      var tempDisplayItems = displayItems;
      final tempGroupByTask = groupByTask; // Temporary selection for grouping

      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Invoice Options'),
          content: HMBColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Display Costs'),
                value: tempDisplayCosts,
                onChanged: (value) {
                  setState(() {
                    tempDisplayCosts = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Display Group Headers'),
                value: tempDisplayGroupHeaders,
                onChanged: (value) {
                  setState(() {
                    tempDisplayGroupHeaders = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Display Items'),
                value: tempDisplayItems,
                onChanged: (value) {
                  setState(() {
                    tempDisplayItems = value ?? true;
                  });
                },
              ),
            ],
          ),
          actions: [
            HMBCancelButton(
              onPressed: () => Navigator.of(context).pop(),
              hint: "Don't send the invoice",
            ),
            HMBButton(
              hint: 'View and optionally send the invoice',
              onPressed: () {
                Navigator.of(context).pop({
                  'displayCosts': tempDisplayCosts,
                  'displayGroupHeaders': tempDisplayGroupHeaders,
                  'displayItems': tempDisplayItems,
                  'groupByTask': tempGroupByTask,
                  'billBookingFee': billBookingFee,
                });
              },
              label: 'OK',
            ),
          ],
        ),
      );
    },
  );
}

Future<Contact?> invoiceGreetingContact({
  required Invoice invoice,
  required Job job,
  required Contact? primaryContact,
}) async =>
    (await resolveInvoiceBillingContact(invoice, job: job)).contact ??
    primaryContact;

Future<Contact> _prepareBillingContactForDelivery(
  Invoice invoice,
  Job job,
) async {
  final resolved = await resolveInvoiceBillingContact(invoice, job: job);
  final contact = await requireInvoiceBillingContact(invoice, job: job);
  if (resolved.source == InvoiceBillingContactSource.jobFallback &&
      invoice.canChangeBillingContact) {
    await DaoInvoice().updateBillingContact(invoice.id, contact.id);
    invoice.billingContactId = contact.id;
  }
  return contact;
}

/// Enabled accounting requires upload before email.
/// Disabled accounting permits direct email.
Future<EmailBlocked> checkInvoiceEmailAvailability({
  required Invoice invoice,
  required Future<void> Function() prepareBillingContact,
  Future<bool> Function()? isAccountingEnabled,
}) async {
  if (invoice.isExternallyDeletedOrVoided) {
    return EmailBlocked(
      blocked: true,
      reason: 'this invoice is voided or deleted.',
    );
  }
  try {
    await prepareBillingContact();
  } on InvoiceException catch (error) {
    return EmailBlocked(blocked: true, reason: error.message);
  }
  if (!invoice.isUploaded()) {
    bool enabled;
    try {
      enabled = await (isAccountingEnabled ?? ExternalAccounting().isEnabled)();
    } catch (_) {
      return EmailBlocked(
        blocked: true,
        reason:
            'accounting settings could not be checked. Retry before sending.',
      );
    }
    if (enabled) {
      return EmailBlocked(
        blocked: true,
        reason:
            'accounting integration is enabled. Upload this invoice before '
            'emailing it.',
      );
    }
  }
  return EmailBlocked(blocked: false, reason: '');
}

/// Generate only the initial/default invoice message. The composer preserves
/// user edits when recipients change.
String invoiceEmailBody({
  required Invoice invoice,
  required List<Contact> recipients,
  String? siteAddress,
}) {
  final names = recipients
      .map(
        (contact) => contact.firstName.trim().isNotEmpty
            ? contact.firstName.trim()
            : contact.fullname.trim(),
      )
      .where((name) => name.isNotEmpty)
      .toSet();
  final greeting = names.isEmpty ? 'Hello' : names.join(', ');
  final site = siteAddress != null && siteAddress.isNotEmpty
      ? '\nSite Address: $siteAddress'
      : '';
  return '$greeting,\n'
      'Please find the attached invoice for your job.\n'
      '$site\n'
      '\nDue Date: ${formatLocalDate(invoice.dueDate, 'yyyy MMM dd')}\n';
}
