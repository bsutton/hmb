import 'dart:convert';

import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../api/external_accounting.dart';
import '../api/xero/models/xero_contact.dart';
import '../api/xero/xero_api.dart';
import '../entity/entity.g.dart';
import '../util/exceptions.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_customer.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_job.dart';
import 'dao_milestone.dart';

class DaoInvoice extends Dao<Invoice> {
  @override
  String get tableName => 'invoice';

  @override
  Invoice fromMap(Map<String, dynamic> map) => Invoice.fromMap(map);

  @override
  Future<List<Invoice>> getAll({String? orderByClause}) async {
    final db = withoutTransaction();
    return toList(await db.query(tableName, orderBy: 'modified_date desc'));
  }

  Future<List<Invoice>> getByJobId(int jobId) async {
    final db = withoutTransaction();
    return toList(
      await db.query(
        tableName,
        where: 'job_id = ?',
        whereArgs: [jobId],
        orderBy: 'id desc',
      ),
    );
  }

  Future<List<Invoice>> getByFilter(String? filter) async {
    final db = withoutTransaction();

    if (Strings.isBlank(filter)) {
      return getAll(orderByClause: 'modified_date desc');
    }

    return toList(
      await db.rawQuery(
        '''
    SELECT i.*
    FROM invoice i
    LEFT JOIN job j ON i.job_id = j.id
    LEFT JOIN customer c ON j.customer_id = c.id
    WHERE i.invoice_num LIKE ? 
       OR i.external_invoice_id LIKE ?
       OR j.summary LIKE ?
       OR c.name LIKE ?
    ORDER BY i.modified_date DESC
  ''',
        [
          '%$filter%', // Filter for invoice_num
          '%$filter%', // Filter for external_invoice_id
          '%$filter%', // Filter for job summary
          '%$filter%', // Filter for customer name
        ],
      ),
    );
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoInvoiceLine().deleteByInvoiceId(id);
    await DaoInvoiceLineGroup().deleteByInvoiceId(id);
    await DaoMilestone().detachFromInvoice(id);

    return super.delete(id);
  }

  Future<void> deleteByJob(int jobId, {Transaction? transaction}) async {
    await withinTransaction(
      transaction,
    ).delete(tableName, where: 'job_id = ?', whereArgs: [jobId]);
  }

  @override
  JuneStateCreator get juneRefresher => InvoiceState.new;

  Future<void> recalculateTotal(int invoiceId) async {
    final lines = await DaoInvoiceLine().getByInvoiceId(invoiceId);
    var total = MoneyEx.zero;
    for (final line in lines) {
      final Money lineTotal;
      switch (line.status) {
        case LineChargeableStatus.normal:
          lineTotal = line.unitPrice.multiplyByFixed(line.quantity);
        case LineChargeableStatus.noCharge:
        case LineChargeableStatus.noChargeHidden:
          lineTotal = MoneyEx.zero;
      }
      total += lineTotal;
    }
    final invoice = await DaoInvoice().getById(invoiceId);
    final updatedInvoice = invoice!.copyWith(totalAmount: total);
    await DaoInvoice().update(updatedInvoice);
  }

  ///
  /// Uploads an invoice and returns the new Invoice Number
  ///
  Future<void> uploadInvoiceToXero(Invoice invoice, XeroApi xeroApi) async {
    // Fetch the job associated with the invoice
    final job = await DaoJob().getById(invoice.jobId);

    final contact = await DaoContact().getPrimaryForJob(job!.id);
    // Fetch the primary contact for the customer
    if (contact == null) {
      throw Exception('You must select a contact for the Job');
    }
    if (Strings.isBlank(contact.emailAddress)) {
      throw Exception('''
You must provide an email address for the Contact ${contact.fullname}''');
    }

    // Check if the contact exists in Xero
    final contactResponse = await xeroApi.getContact(contact.fullname);
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
        final xeroContact = XeroContact.fromContact(contact);
        final createContactResponse = await xeroApi.createContact(
          xeroContact.toJson(),
        );

        if (createContactResponse.statusCode == 200) {
          /// its json.
          // ignore: avoid_dynamic_calls
          xeroContactId =
              /// its json.
              // ignore: avoid_dynamic_calls
              (jsonDecode(createContactResponse.body)['Contacts'] as List)
                      .first['ContactID']
                  as String;
          // Update the local contact with the Xero contact ID
          await DaoContact().update(
            contact.copyWith(xeroContactId: xeroContactId),
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
      throw Exception(
        'Failed to create invoice in Xero: ${createInvoiceResponse.body}',
      );
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
  }

  Future<List<String>> getEmailsByInvoice(Invoice invoice) async {
    final job = await DaoJob().getById(invoice.jobId);
    final customer = await DaoCustomer().getById(job!.customerId);
    final contacts = await DaoContact().getByCustomer(customer!.id);

    /// make sure we have no dups.
    final emails = <String>{};

    for (final contact in contacts) {
      if (Strings.isNotBlank(contact.emailAddress)) {
        emails.add(contact.emailAddress.trim());
      }
    }

    return emails.toList();
  }

  Future<void> markSent(Invoice invoice) async {
    invoice.sent = true;

    await update(invoice);

    if (await ExternalAccounting().isEnabled()) {
      final xeroApi = XeroApi();
      await xeroApi.login();

      await xeroApi.markApproved(invoice);
      await xeroApi.markAsSent(invoice);
    }
  }
}

/// Used to notify the UI that the time entry has changed.
class InvoiceState extends JuneState {
  InvoiceState();
}
