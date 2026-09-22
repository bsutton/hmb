@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_contact_role.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/dao/invoice_billing_contact.dart';
import 'package:hmb/dao/job_billing_contact.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  Future<Job> makeJob() => createJobWithCustomer(
    billingType: BillingType.timeAndMaterial,
    hourlyRate: MoneyEx.dollars(95),
  );

  test('business referrer changes retain billing and contact roles', () async {
    final job = await makeJob();
    final businessJob = await makeJob();
    final replacementJob = await makeJob();
    job
      ..referrerCustomerId = businessJob.customerId
      ..billingParty = BillingParty.referrer;
    await DaoJob().update(job);
    // Exercise the legacy fallback, not only the explicit Bill To field.
    job.billToCustomerId = null;
    await DaoJob().update(job);
    final before = await DaoJobParty().getByJob(job.id);

    await DaoJob().setReferringCustomer(job.id, replacementJob.customerId);
    var saved = (await DaoJob().getById(job.id))!;
    expect(saved.customerId, job.customerId);
    expect(saved.referrerCustomerId, replacementJob.customerId);
    expect(saved.billingCustomerId, businessJob.customerId);
    await DaoJob().setReferringCustomer(job.id, null);
    saved = (await DaoJob().getById(job.id))!;
    expect(saved.referrerCustomerId, isNull);
    expect(saved.billingCustomerId, businessJob.customerId);
    expect(await DaoCustomer().getById(businessJob.customerId), isNotNull);
    expect(
      (await DaoJobParty().getByJob(job.id)).map((party) => party.id),
      before.map((party) => party.id),
    );
  });

  Future<Contact> makeContact({
    int? roleId,
    String roleDescription = '',
  }) async {
    final contact = Contact.forInsert(
      firstName: 'Sample',
      surname: 'Person',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: 'sample@example.com',
      defaultRoleId: roleId,
      roleDescription: roleDescription,
    );
    await DaoContact().insert(contact);
    return contact;
  }

  test(
    'contact defaults are canonical roles, not independent free text',
    () async {
      final contact = await makeContact(
        roleDescription: ' Custom Coordinator ',
      );
      final again = await makeContact(roleDescription: 'custom coordinator');
      expect(contact.defaultRoleId, isNotNull);
      expect(contact.defaultRoleId, again.defaultRoleId);
      await DaoContactRole().rename(contact.defaultRoleId!, 'Coordinator');
      final saved = (await DaoContact().getById(contact.id))!;
      expect(saved.roleDescription, 'Coordinator');
      await DaoContact().update(
        saved.copyWith(clearDefaultRole: true, roleDescription: ''),
      );
      expect((await DaoContact().getById(contact.id))!.defaultRoleId, isNull);
    },
  );

  test(
    'standard roles are protected and used custom roles cannot be deleted',
    () async {
      await expectLater(
        DaoContactRole().rename(ContactRole.primary, 'Changed'),
        throwsException,
      );
      await expectLater(
        DaoContactRole().delete(ContactRole.billing),
        throwsException,
      );
      final roleId = await DaoContactRole().create('Inspector');
      final contact = await makeContact(roleId: roleId);
      await expectLater(DaoContactRole().delete(roleId), throwsException);
      await DaoContact().update(
        contact.copyWith(clearDefaultRole: true, roleDescription: ''),
      );
      await DaoContactRole().delete(roleId);
      expect(await DaoContactRole().getById(roleId), isNull);
    },
  );

  test(
    'multiple role rows retain primary compatibility and reject duplicates',
    () async {
      final job = await makeJob();
      final parties = DaoJobParty();
      await parties.save(
        jobId: job.id,
        contactId: job.contactId!,
        roleId: ContactRole.projectManager,
      );
      final list = await parties.getByJob(job.id);
      expect(list.where((p) => p.contact.id == job.contactId), hasLength(3));
      expect((await DaoContact().getPrimaryForJob(job.id))!.id, job.contactId);
      await expectLater(
        parties.save(
          jobId: job.id,
          contactId: job.contactId!,
          roleId: ContactRole.projectManager,
        ),
        throwsException,
      );
      await DaoJob().update(job.copyWith(summary: 'Unrelated edit'));
      expect(await parties.getByJob(job.id), hasLength(3));
    },
  );

  test(
    'primary replacement requires consent; removing a role keeps its contact',
    () async {
      final job = await makeJob();
      final other = await makeContact();
      final parties = DaoJobParty();
      await expectLater(
        parties.save(
          jobId: job.id,
          contactId: other.id,
          roleId: ContactRole.primary,
        ),
        throwsException,
      );
      expect((await DaoJob().getById(job.id))!.contactId, job.contactId);
      await parties.save(
        jobId: job.id,
        contactId: other.id,
        roleId: ContactRole.primary,
        replaceSingleton: true,
      );
      expect((await DaoJob().getById(job.id))!.contactId, other.id);
      final row = (await parties.getByJob(job.id))
          .singleWhere((p) => p.role.id == ContactRole.primary);
      await parties.delete(job.id, row.id);
      expect((await DaoJob().getById(job.id))!.contactId, isNull);
      expect(await DaoContact().getById(other.id), isNotNull);
    },
  );

  test('changing a contact default never changes their job role', () async {
    final job = await makeJob();
    final contact = (await DaoContact().getById(job.contactId))!;
    await DaoContact().update(
      contact.copyWith(defaultRoleId: ContactRole.owner),
    );
    expect(
      (await DaoJobParty().getByJob(job.id)).map((p) => p.role.id),
      containsAll([ContactRole.primary, ContactRole.billing]),
    );
    expect(
      (await DaoJobParty().getByJob(job.id))
          .any((p) => p.role.id == ContactRole.owner),
      isFalse,
    );
  });

  test(
    'billing assignment infers Bill To but keeps an explicit customer',
    () async {
      final job = await makeJob();
      final other = await makeJob();
      final contact = (await DaoContact().getById(other.contactId))!;
      final customer = (await DaoCustomer().getById(other.customerId))!;
      await DaoContactCustomer().insertJoin(contact, customer);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: contact.id,
        roleId: ContactRole.billing,
        replaceSingleton: true,
      );
      var saved = (await DaoJob().getById(job.id))!;
      expect(saved.billToCustomerId, other.customerId);
      saved.billToCustomerId = job.customerId;
      await DaoJob().update(saved);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: contact.id,
        roleId: ContactRole.billing,
        replaceSingleton: true,
      );
      saved = (await DaoJob().getById(job.id))!;
      expect(saved.billToCustomerId, job.customerId);
    },
  );

  test(
    'billing order: explicit, customer default, primary, only distinct contact',
    () async {
      final original = await makeJob();
      final primary = await makeContact();
      final explicit = await makeContact();
      final job = (await DaoJob().getById(original.id))!
        ..contactId = primary.id
        ..billingContactId = explicit.id;
      await DaoJob().update(job);
      expect((await resolveJobBillingContact(job)).contact!.id, explicit.id);
      job.billingContactId = null;
      await DaoJob().update(job);
      expect(
        (await resolveJobBillingContact(job)).contact!.id,
        original.contactId,
      );
      await testDb!.update(
        'customer',
        {'billing_contact_id': null},
        where: 'id = ?',
        whereArgs: [job.customerId],
      );
      expect(
        (await resolveJobBillingContact(job)).source,
        JobBillingContactSource.primary,
      );
      job.contactId = null;
      await DaoJob().update(job);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: primary.id,
        roleId: ContactRole.site,
      );
      await DaoJobParty().save(
        jobId: job.id,
        contactId: primary.id,
        roleId: ContactRole.projectManager,
      );
      expect(
        (await resolveJobBillingContact(job)).source,
        JobBillingContactSource.onlyContact,
      );
      await DaoJobParty().save(
        jobId: job.id,
        contactId: explicit.id,
        roleId: ContactRole.authoriser,
      );
      expect(
        (await resolveJobBillingContact(job)).source,
        JobBillingContactSource.missing,
      );
    },
  );

  test(
    'migration fallback is visible and deliberate billing changes replace it',
    () async {
      final job = await makeJob();
      final oldRecipient = await makeContact();
      job.billingContactId = null;
      await DaoJob().update(job);
      // Seed a migrated arrangement after the deliberate billing change.
      job.legacyBillingContactId = oldRecipient.id;
      await DaoJob().update(job);
      final result = await resolveJobBillingContact(job);
      expect(result.source, JobBillingContactSource.preserved);
      expect(result.contact!.id, oldRecipient.id);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: job.contactId!,
        roleId: ContactRole.billing,
      );
      expect((await DaoJob().getById(job.id))!.legacyBillingContactId, isNull);
    },
  );

  test(
    'invoices retain their recipient and billed customer after job changes',
    () async {
      final job = await makeJob();
      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: MoneyEx.dollars(100),
        billingContactId: null,
      );
      await DaoInvoice().insert(invoice);
      final otherJob = await makeJob();
      job
        ..billToCustomerId = otherJob.customerId
        ..billingContactId = otherJob.contactId;
      await DaoJob().update(job);
      final saved = (await DaoInvoice().getById(invoice.id))!;
      expect(saved.billingCustomerId, invoice.billingCustomerId);
      expect(saved.billingCustomerId, isNot(otherJob.customerId));
      expect(
        (await resolveInvoiceBillingContact(saved)).contact!.id,
        invoice.billingContactId,
      );
      final ledger = DebtorLedgerService();
      final transaction = await ledger.recordInvoice(saved);
      expect(transaction.debtorCustomerId, invoice.billingCustomerId);
      final payment = await ledger.recordPayment(
        invoiceId: saved.id,
        amount: MoneyEx.dollars(10),
      );
      expect(payment.customerId, invoice.billingCustomerId);
    },
  );

  test(
    'rate changes retain preserved recipient; removing billing does not',
    () async {
      final job = await makeJob();
      job.legacyBillingContactId = job.billingContactId;
      await DaoJob().update(job);
      job.hourlyRate = MoneyEx.dollars(110);
      await DaoJob().update(job);
      expect(
        (await DaoJob().getById(job.id))!.legacyBillingContactId,
        job.billingContactId,
      );
      final billing = (await DaoJobParty().getByJob(job.id))
          .singleWhere((party) => party.role.id == ContactRole.billing);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: billing.contact.id,
        roleId: ContactRole.owner,
        assignmentId: billing.id,
      );
      final saved = (await DaoJob().getById(job.id))!;
      expect(saved.billingContactId, isNull);
      expect(saved.legacyBillingContactId, isNull);
    },
  );
}
