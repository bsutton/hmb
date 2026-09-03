/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the exceptions described in the repository LICENSE.
*/

import 'package:strings/strings.dart';

import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import 'dao_contact.dart';
import 'dao_customer.dart';
import 'dao_job.dart';

enum InvoiceBillingContactSource { invoice, jobFallback, missing }

class ResolvedInvoiceBillingContact {
  final Contact? contact;
  final InvoiceBillingContactSource source;

  const ResolvedInvoiceBillingContact({
    required this.contact,
    required this.source,
  });

  bool get hasEmail => Strings.isNotBlank(contact?.bestEmail);
}

Future<ResolvedInvoiceBillingContact> resolveInvoiceBillingContact(
  Invoice invoice, {
  Job? job,
}) async {
  final invoiceContact = await DaoContact().getById(invoice.billingContactId);
  if (invoiceContact != null) {
    return ResolvedInvoiceBillingContact(
      contact: invoiceContact,
      source: InvoiceBillingContactSource.invoice,
    );
  }

  final resolvedJob = job ?? await DaoJob().getById(invoice.jobId);
  final jobContact = resolvedJob == null
      ? null
      : await DaoContact().getBillingContactByJob(resolvedJob);
  return ResolvedInvoiceBillingContact(
    contact: jobContact,
    source: jobContact == null
        ? InvoiceBillingContactSource.missing
        : InvoiceBillingContactSource.jobFallback,
  );
}

Future<Contact> requireInvoiceBillingContact(
  Invoice invoice, {
  Job? job,
}) async {
  final resolved = await resolveInvoiceBillingContact(invoice, job: job);
  final contact = resolved.contact;
  if (contact == null) {
    throw InvoiceException(
      'Select a billing contact for invoice #${invoice.bestNumber}.',
    );
  }
  if (!resolved.hasEmail) {
    throw InvoiceException(
      'Billing contact ${contact.fullname.trim()} does not have an email '
      'address.',
    );
  }
  return contact;
}

Future<Customer?> getBillingCustomerForJob(Job job) => DaoCustomer().getById(
  job.billingParty == BillingParty.referrer
      ? job.referrerCustomerId
      : job.customerId,
);
