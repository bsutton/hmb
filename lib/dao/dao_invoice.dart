import 'dart:convert';

import 'package:june/june.dart';
import 'package:money2/money2.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strings/strings.dart';

import '../entity/_index.g.dart';
import '../invoicing/xero/models/xero_contact.dart';
import '../invoicing/xero/xero_api.dart';
import '../util/exceptions.dart';
import '../util/money_ex.dart';
import 'dao.dart';
import 'dao_contact.dart';
import 'dao_invoice_line.dart';
import 'dao_invoice_line_group.dart';
import 'dao_job.dart';

class DaoInvoice extends Dao<Invoice> {
  @override
  String get tableName => 'invoice';

  @override
  Invoice fromMap(Map<String, dynamic> map) => Invoice.fromMap(map);

  @override
  Future<List<Invoice>> getAll(
      {String? orderByClause, Transaction? transaction}) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps =
        await db.query(tableName, orderBy: 'modified_date desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<List<Invoice>> getByJobId(int jobId,
      [Transaction? transaction]) async {
    final db = getDb(transaction);
    final List<Map<String, dynamic>> maps = await db.query(tableName,
        where: 'job_id = ?', whereArgs: [jobId], orderBy: 'id desc');
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    await DaoInvoiceLine().deleteByInvoiceId(id);
    await DaoInvoiceLineGroup().deleteByInvoiceId(id);

    return super.delete(id);
  }

  Future<void> deleteByJob(int jobId, {Transaction? transaction}) async {
    await getDb(transaction)
        .delete(tableName, where: 'job_id = ?', whereArgs: [jobId]);
  }

  @override
  JuneStateCreator get juneRefresher => InvoiceState.new;

  Future<void> recalculateTotal(int invoiceId) async {
    final lines = await DaoInvoiceLine().getByInvoiceId(invoiceId);
    var total = MoneyEx.zero;
    for (final line in lines) {
      final Money lineTotal;
      switch (line.status) {
        case LineStatus.normal:
          lineTotal = line.unitPrice.multiplyByFixed(line.quantity);
        case LineStatus.noCharge:
        case LineStatus.noChargeHidden:
          lineTotal = MoneyEx.zero;
      }
      total += lineTotal;
    }
    final invoice = await DaoInvoice().getById(invoiceId);
    final updatedInvoice = invoice!.copyWith(totalAmount: total);
    await DaoInvoice().update(updatedInvoice);
  }

  /// Uploads an invoice and returns the new Invoice Number
  Future<void> uploadInvoiceToXero(Invoice invoice, XeroApi xeroApi) async {
    // Fetch the job associated with the invoice
    final job = await DaoJob().getById(invoice.jobId);

    // Fetch the primary contact for the customer
    final contact = await DaoContact().getPrimaryForCustomer(job!.customerId);
    if (contact == null) {
      throw Exception('Primary contact for the customer not found');
    }

    // Check if the contact exists in Xero
    final contactResponse = await xeroApi.getContact(contact.fullname);
    String xeroContactId;

    if (contactResponse.statusCode == 200) {
      final contacts =
          // ignore: avoid_dynamic_calls
          jsonDecode(contactResponse.body)['Contacts'] as List<dynamic>;
      if (contacts.isNotEmpty) {
        // ignore: avoid_dynamic_calls
        xeroContactId = contacts.first['ContactID'] as String;
      } else {
        // Create the contact in Xero if it doesn't exist
        final xeroContact = XeroContact.fromContact(contact);
        final createContactResponse =
            await xeroApi.createContact(xeroContact.toJson());

        if (createContactResponse.statusCode == 200) {
          // ignore: avoid_dynamic_calls
          xeroContactId =
              // ignore: avoid_dynamic_calls
              (jsonDecode(createContactResponse.body)['Contacts'] as List)
                  .first['ContactID'] as String;
          // Update the local contact with the Xero contact ID
          await DaoContact()
              .update(contact.copyWith(xeroContactId: xeroContactId));
        } else {
          throw Exception('Failed to create contact in Xero');
        }
      }
    } else {
      throw InvoiceException(
          '''Failed to fetch contact from Xero Error: ${contactResponse.reasonPhrase}''');
    }

    // Create the invoice in Xero
    final xeroInvoice = await invoice.toXeroInvoice(invoice);

    final createInvoiceResponse = await xeroApi.createInvoice(xeroInvoice);
    if (createInvoiceResponse.statusCode != 200) {
      throw Exception(
          'Failed to create invoice in Xero: ${createInvoiceResponse.body}');
    }
    final responseBody = jsonDecode(createInvoiceResponse.body);
    // ignore: avoid_dynamic_calls
    final invoiceNum = responseBody['Invoices'][0]['InvoiceNumber'] as String;
    // ignore: avoid_dynamic_calls
    final invoiceId = responseBody['Invoices'][0]['InvoiceID'] as String;

    await DaoInvoice().update(
        invoice.copyWith(invoiceNum: invoiceNum, externalInvoiceId: invoiceId));

    await xeroApi.markAsAuthorised(invoice);
  }

  Future<List<String>> getEmailsByInvoice(Invoice invoice) async {
    final job = await DaoJob().getById(invoice.jobId);
    final customer = await DaoCustomer().getById(job!.customerId);
    final contacts = await DaoContact().getByCustomer(customer!.id);

    final emails = <String>[];

    for (final contact in contacts) {
      if (Strings.isNotBlank(contact.emailAddress)) {
        emails.add(contact.emailAddress);
      }
    }

    return emails;
  }
}

/// Used to notify the UI that the time entry has changed.
class InvoiceState extends JuneState {
  InvoiceState();
}
