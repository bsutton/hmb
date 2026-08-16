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

@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/invoicing/pdf/generate_invoice_pdf.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outputDirectory;

  setUp(() async {
    outputDirectory = Directory.systemTemp.createTempSync(
      'hmb_invoice_pdf_test_',
    );
    PathProviderPlatform.instance = _FakePathProvider(outputDirectory.path);
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
    outputDirectory.deleteSync(recursive: true);
  });

  test('overflowing invoice generates multiple PDF pages', () async {
    final contact = Contact.forInsert(
      firstName: 'Pat',
      surname: 'Customer',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: 'pat@example.com',
    );
    await DaoContact().insert(contact);

    final customer = Customer.forInsert(
      name: 'Pat Customer',
      description: '',
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: contact.id,
    );
    await DaoCustomer().insert(customer);

    final job = Job.forInsert(
      customerId: customer.id,
      summary: 'Invoice pagination test',
      description: '',
      siteId: null,
      contactId: contact.id,
      status: JobStatus.startingStatus,
      hourlyRate: MoneyEx.dollars(100),
      bookingFee: MoneyEx.zero,
      billingContactId: contact.id,
    );
    await DaoJob().insert(job);

    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: MoneyEx.zero,
      billingContactId: contact.id,
    );
    await DaoInvoice().insert(invoice);

    final group = InvoiceLineGroup.forInsert(
      invoiceId: invoice.id,
      name: 'Test items',
    );
    await DaoInvoiceLineGroup().insert(group);

    for (var index = 1; index <= 55; index++) {
      await DaoInvoiceLine().insert(
        InvoiceLine.forInsert(
          invoiceId: invoice.id,
          invoiceLineGroupId: group.id,
          description: 'Pagination test item $index',
          quantity: Fixed.one,
          unitPrice: MoneyEx.dollars(10),
          lineTotal: MoneyEx.dollars(10),
        ),
      );
    }

    final file = await generateInvoicePdf(
      invoice,
      displayItems: true,
      displayCosts: true,
      displayGroupHeaders: false,
    );
    final pdfSource = latin1.decode(
      await file.readAsBytes(),
      allowInvalid: true,
    );
    final pageCount = RegExp(
      r'/Type\s*/Page(?!s)\b',
    ).allMatches(pdfSource).length;

    expect(file.existsSync(), isTrue);
    expect(pageCount, greaterThan(1));
  });
}

class _FakePathProvider
    with Fake, MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
