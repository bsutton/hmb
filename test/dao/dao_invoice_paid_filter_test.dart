import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('getByFilter excludes paid invoices by default', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Invoice paid filter job',
    );

    final unpaid = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
    );
    await DaoInvoice().insert(unpaid);
    await DaoInvoice().update(unpaid.copyWith(invoiceNum: 'INV-UNPAID'));

    final paid = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(2000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      sent: true,
      paid: true,
      paidDate: DateTime.now(),
    );
    await DaoInvoice().insert(paid);
    await DaoInvoice().update(paid.copyWith(invoiceNum: 'INV-PAID'));

    final hiddenPaid = await DaoInvoice().getByFilter(null);
    final all = await DaoInvoice().getByFilter(null, includePaid: true);

    expect(hiddenPaid.map((i) => i.invoiceNum), isNot(contains('INV-PAID')));
    expect(hiddenPaid.map((i) => i.invoiceNum), contains('INV-UNPAID'));
    expect(
      all.map((i) => i.invoiceNum),
      containsAll(['INV-UNPAID', 'INV-PAID']),
    );
  });

  test('getByFilter can limit paid invoices to a recent window', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Invoice recent paid filter job',
    );

    final unpaid = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
    );
    await DaoInvoice().insert(unpaid);
    await DaoInvoice().update(unpaid.copyWith(invoiceNum: 'INV-OPEN'));

    final recentPaid = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(2000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      paid: true,
      paidDate: DateTime.now().subtract(const Duration(days: 10)),
    );
    await DaoInvoice().insert(recentPaid);
    await DaoInvoice().update(recentPaid.copyWith(invoiceNum: 'INV-RECENT'));

    final oldPaid = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(3000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      paid: true,
      paidDate: DateTime.now().subtract(const Duration(days: 45)),
    );
    await DaoInvoice().insert(oldPaid);
    await DaoInvoice().update(oldPaid.copyWith(invoiceNum: 'INV-OLD'));

    final visible = await DaoInvoice().getByFilter(
      null,
      includePaid: true,
      paidSince: DateTime.now().subtract(const Duration(days: 30)),
    );

    expect(visible.map((i) => i.invoiceNum), contains('INV-OPEN'));
    expect(visible.map((i) => i.invoiceNum), contains('INV-RECENT'));
    expect(visible.map((i) => i.invoiceNum), isNot(contains('INV-OLD')));
  });

  test('getByFilter excludes deleted and voided invoices by default', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Invoice external sync filter job',
    );

    final open = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
    );
    await DaoInvoice().insert(open);

    final deleted = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(2000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      externalSyncStatus: InvoiceExternalSyncStatus.deleted,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(deleted);

    final voided = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(3000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      externalSyncStatus: InvoiceExternalSyncStatus.voided,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(voided);

    final visible = await DaoInvoice().getByFilter(null, includePaid: true);
    final all = await DaoInvoice().getByFilter(
      null,
      includePaid: true,
      includeDeletedOrVoided: true,
    );

    expect(visible.map((i) => i.id), [open.id]);
    expect(all.map((i) => i.id), containsAll([open.id, deleted.id, voided.id]));
  });

  test('getUploadedUnpaid ignores Xero deleted and voided invoices', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Invoice uploaded unpaid filter job',
    );

    final open = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      externalInvoiceId: 'ext-open',
      externalSyncStatus: InvoiceExternalSyncStatus.linked,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(open);

    final deleted = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(2000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      externalInvoiceId: 'ext-deleted',
      externalSyncStatus: InvoiceExternalSyncStatus.deleted,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(deleted);

    final voided = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(3000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      externalInvoiceId: 'ext-voided',
      externalSyncStatus: InvoiceExternalSyncStatus.voided,
      paymentSource: InvoicePaymentSource.xero,
    );
    await DaoInvoice().insert(voided);

    final pending = await DaoInvoice().getUploadedUnpaid();

    expect(pending.map((invoice) => invoice.externalInvoiceId), ['ext-open']);
  });

  test('legacy invoice can be converted to manual tracking', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Invoice manual conversion job',
    );

    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: job.billingContactId,
      paymentSource: InvoicePaymentSource.unknown,
    );
    await DaoInvoice().insert(invoice);

    await DaoInvoice().convertToManualTracking(invoice.id);
    final updated = await DaoInvoice().getById(invoice.id);

    expect(updated!.paymentSource, InvoicePaymentSource.manual);
    expect(updated.canMarkPaidManually, isTrue);
  });

  test(
    'getByFilter matches job number, customer name and contact name',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Kitchen refit',
      );

      final contact = (await DaoContact().getById(
        job.contactId,
      ))!.copyWith(firstName: 'Zelda', surname: 'Zimmer');
      await DaoContact().update(contact);

      final customer = (await DaoCustomer().getById(
        job.customerId,
      ))!.copyWith(name: 'Acme Plumbing');
      await DaoCustomer().update(customer);

      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
        billingContactId: contact.id,
      );
      await DaoInvoice().insert(invoice);
      await DaoInvoice().update(invoice.copyWith(invoiceNum: 'INV-SEARCH'));

      final byJobId = await DaoInvoice().getByFilter('${job.id}');
      final byCustomer = await DaoInvoice().getByFilter('acme');
      final byContact = await DaoInvoice().getByFilter('zelda');

      expect(byJobId.map((i) => i.invoiceNum), contains('INV-SEARCH'));
      expect(byCustomer.map((i) => i.invoiceNum), contains('INV-SEARCH'));
      expect(byContact.map((i) => i.invoiceNum), contains('INV-SEARCH'));
    },
  );
}
