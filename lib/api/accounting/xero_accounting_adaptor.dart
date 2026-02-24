import 'dart:async';
import 'dart:convert';

import 'package:strings/strings.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_job.dart';
import '../../entity/invoice.dart';
import '../../util/dart/exceptions.dart';
import '../xero/models/xero_contact.dart';
import '../xero/xero_api.dart';
import '../xero/xero_extract_error_message.dart';
import '../xero/xero_invoice_payment_sync_service.dart';
import 'accounting_adaptor.dart';

class XeroAccountingAdaptor extends AccountingAdaptor {
  final xeroApi = XeroApi();

  @override
  Future<void> login() async {
    await xeroApi.login();
  }

  @override
  Future<void> markSent(Invoice invoice) async {
    await xeroApi.markAsSent(invoice);
  }

  @override
  Future<void> markApproved(Invoice invoice) async {
    await xeroApi.markApproved(invoice);
  }

  @override
  ///
  /// Uploads an invoice and returns the new Invoice Number
  ///
  Future<void> uploadInvoice(Invoice invoice) async {
    // Fetch the job associated with the invoice
    final job = await DaoJob().getById(invoice.jobId);

    final billingContact = await DaoContact().getBillingContactByJob(job!);

    // Fetch the primary contact for the customer
    if (billingContact == null) {
      throw Exception('You must select a contact for the Job');
    }
    if (Strings.isBlank(billingContact.emailAddress)) {
      throw Exception(
        '''
You must provide an email address for the Contact ${billingContact.fullname}''',
      );
    }

    // Check if the contact exists in Xero
    final contactResponse = await xeroApi.getContact(billingContact.fullname);
    String xeroContactId;

    if (contactResponse.statusCode == 200) {
      final contacts =
          /// its json.
          // ignore: avoid_dynamic_calls
          jsonDecode(contactResponse.body)['Contacts'] as List<dynamic>;
      if (contacts.isNotEmpty) {
        /// its json.
        // ignore: avoid_dynamic_calls
        xeroContactId = contacts.first['ContactID'] as String;
      } else {
        // Create the contact in Xero if it doesn't exist
        final xeroContact = XeroContact.fromContact(billingContact);
        final createContactResponse = await xeroApi.createContact(
          xeroContact.toJson(),
        );

        if (createContactResponse.statusCode == 200) {
          /// its json.
          xeroContactId =
              /// its json.
              // ignore: avoid_dynamic_calls
              (jsonDecode(createContactResponse.body)['Contacts'] as List)
                      .first['ContactID']
                  as String;
          // Update the local contact with the Xero contact ID
          await DaoContact().update(
            billingContact.copyWith(xeroContactId: xeroContactId),
          );
        } else {
          throw Exception('Failed to create contact in Xero');
        }
      }
    } else {
      throw InvoiceException(
        '''Failed to fetch contact from Xero Error: ${contactResponse.reasonPhrase}''',
      );
    }

    // Create the invoice in Xero
    final xeroInvoice = await invoice.toXeroInvoice(invoice);

    final createInvoiceResponse = await xeroApi.uploadInvoice(xeroInvoice);
    if (createInvoiceResponse.statusCode != 200) {
      final error = extractXeroErrorMessage(createInvoiceResponse.body);
      throw Exception(error);
    }
    final responseBody = jsonDecode(createInvoiceResponse.body);

    /// its json.
    // ignore: avoid_dynamic_calls
    final invoiceNum = responseBody['Invoices'][0]['InvoiceNumber'] as String;

    /// its json.
    // ignore: avoid_dynamic_calls
    final invoiceId = responseBody['Invoices'][0]['InvoiceID'] as String;

    final completedInvoice = invoice.copyWith(
      invoiceNum: invoiceNum,
      externalInvoiceId: invoiceId,
    );

    await DaoInvoice().update(completedInvoice);
    unawaited(XeroInvoicePaymentSyncService().sync(force: true));
  }
}
