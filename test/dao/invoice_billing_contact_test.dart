import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/invoice_billing_contact.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:test/test.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('explicit invoice contact wins over the current job contact', () async {
    final fixture = await _createFixture();
    final invoice = _invoice(
      fixture.job,
      billingContactId: fixture.invoiceContact.id,
    );

    final resolved = await resolveInvoiceBillingContact(
      invoice,
      job: fixture.job,
    );

    expect(resolved.source, InvoiceBillingContactSource.invoice);
    expect(resolved.contact?.id, fixture.invoiceContact.id);
  });

  test('missing invoice email does not silently fall back to job', () async {
    final fixture = await _createFixture(invoiceEmail: '');
    final invoice = _invoice(
      fixture.job,
      billingContactId: fixture.invoiceContact.id,
    );

    await expectLater(
      requireInvoiceBillingContact(invoice, job: fixture.job),
      throwsA(
        predicate(
          (error) => error.toString().contains(
            'Billing contact Invoice Contact does not have an email address.',
          ),
        ),
      ),
    );
  });

  test('legacy invoice without contact falls back to job contact', () async {
    final fixture = await _createFixture();
    final invoice = _invoice(fixture.job, billingContactId: null);

    final resolved = await resolveInvoiceBillingContact(
      invoice,
      job: fixture.job,
    );

    expect(resolved.source, InvoiceBillingContactSource.jobFallback);
    expect(resolved.contact?.id, fixture.jobContact.id);
  });

  test('draft billing contact update persists', () async {
    final fixture = await _createFixture();
    final invoice = _invoice(
      fixture.job,
      billingContactId: fixture.jobContact.id,
    );
    await DaoInvoice().insert(invoice);

    await DaoInvoice().updateBillingContact(
      invoice.id,
      fixture.invoiceContact.id,
    );

    final reloaded = await DaoInvoice().getById(invoice.id);
    expect(reloaded?.billingContactId, fixture.invoiceContact.id);
  });

  test('sent invoice billing contact cannot be changed', () async {
    final fixture = await _createFixture();
    final invoice = _invoice(
      fixture.job,
      billingContactId: fixture.jobContact.id,
    )..sent = true;
    await DaoInvoice().insert(invoice);

    await expectLater(
      DaoInvoice().updateBillingContact(invoice.id, fixture.invoiceContact.id),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('billing contact cannot be changed'),
        ),
      ),
    );
  });
}

class _Fixture {
  final Job job;
  final Contact jobContact;
  final Contact invoiceContact;

  const _Fixture(this.job, this.jobContact, this.invoiceContact);
}

Future<_Fixture> _createFixture({
  String invoiceEmail = 'invoice@example.com',
}) async {
  final job = await createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.zero,
    summary: 'Billing contact job',
  );
  final jobContact = (await DaoContact().getById(job.contactId))!;
  job.billingContactId = jobContact.id;
  await DaoJob().update(job);

  final invoiceContact = Contact.forInsert(
    firstName: 'Invoice',
    surname: 'Contact',
    mobileNumber: '',
    landLine: '',
    officeNumber: '',
    emailAddress: invoiceEmail,
  );
  await DaoContact().insert(invoiceContact);
  return _Fixture(job, jobContact, invoiceContact);
}

Invoice _invoice(Job job, {required int? billingContactId}) =>
    Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: MoneyEx.zero,
      billingContactId: billingContactId,
    );
