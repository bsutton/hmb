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

  InvoiceLine line(
    int groupId,
    int dollars, {
    LineChargeableStatus status = LineChargeableStatus.normal,
  }) => InvoiceLine.forInsert(
    invoiceId: 1,
    invoiceLineGroupId: groupId,
    description: 'Saved invoice item',
    quantity: Fixed.one,
    unitPrice: MoneyEx.dollars(dollars),
    lineTotal: MoneyEx.dollars(dollars),
    status: status,
  );

  test('missing groups retain all charges and credits as ungrouped', () async {
    final lines = [line(-1, 100), line(-2, -20), line(-1, 30)];
    final groups = await groupByInvoiceLineGroup(lines);

    expect(groups, hasLength(1));
    expect(groups.single.key, isNull);
    expect(groups.single.title, 'Ungrouped');
    expect(groups.single.items, orderedEquals(lines));
    expect(groups.single.total, MoneyEx.dollars(110));
    expect(groups.single.quantity, Fixed.fromNum(3));
  });

  test('hidden orphan lines do not appear or contribute to totals', () async {
    final visible = line(-1, 40);
    final groups = await groupByInvoiceLineGroup([
      visible,
      line(-1, 90, status: LineChargeableStatus.noChargeHidden),
      line(-2, 70, status: LineChargeableStatus.noChargeHidden),
      line(-1, 0, status: LineChargeableStatus.noCharge),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.items, hasLength(2));
    expect(groups.single.items.first, same(visible));
    expect(groups.single.total, MoneyEx.dollars(40));
    expect(await groupByInvoiceLineGroup([]), isEmpty);
  });

  test('invoice PDF preserves groups and recovers deleted headers', () async {
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

    final savedLines = await DaoInvoiceLine().getByInvoiceId(invoice.id);
    final grouped = await groupByInvoiceLineGroup(savedLines);
    expect(grouped.single.title, 'Test items');
    expect(grouped.single.total, MoneyEx.dollars(550));
    expect(grouped.single.items, hasLength(55));

    final mixed = await groupByInvoiceLineGroup([
      savedLines.first,
      savedLines.first.copyWith(invoiceLineGroupId: -1),
      savedLines.first.copyWith(status: LineChargeableStatus.noChargeHidden),
    ]);
    expect(mixed.map((group) => group.title), ['Test items', 'Ungrouped']);
    expect(mixed.map((group) => group.total), [
      MoneyEx.dollars(10),
      MoneyEx.dollars(10),
    ]);
    expect(mixed.first.items, hasLength(1));

    final wrongInvoice = await groupByInvoiceLineGroup([
      savedLines.first.copyWith(invoiceId: invoice.id + 1),
    ]);
    expect(wrongInvoice.single.title, 'Ungrouped');
    expect(wrongInvoice.single.total, MoneyEx.dollars(10));

    // Model a partially restored database: saved charges survive their header.
    await testDb!.execute('PRAGMA foreign_keys = OFF');
    await DaoInvoiceLineGroup().delete(group.id);
    await testDb!.execute('PRAGMA foreign_keys = ON');
    final recovered = await groupByInvoiceLineGroup(savedLines);
    expect(recovered.single.title, 'Ungrouped');
    expect(recovered.single.total, MoneyEx.dollars(550));
    expect(recovered.single.items, orderedEquals(savedLines));
    for (final displayItems in [true, false]) {
      final recoveredFile = await generateInvoicePdf(
        invoice,
        displayItems: displayItems,
        displayCosts: true,
        displayGroupHeaders: true,
      );
      expect(await recoveredFile.length(), greaterThan(0));
    }
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
