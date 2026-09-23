@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_contact_role.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
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

  test(
    'usage and reassignment include defaults and every job assignment',
    () async {
      final job = await makeJob();
      final source = await DaoContactRole().create('Inspector');
      final target = await DaoContactRole().create('Surveyor');
      final contact = (await DaoContact().getById(job.contactId))!
        ..defaultRoleId = source;
      await DaoContact().update(contact);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: contact.id,
        roleId: source,
      );
      final usage = await DaoContactRole().getUsage(source);
      expect(usage.contacts.single.id, contact.id);
      expect(usage.assignments.single.job.id, job.id);
      expect(usage.assignments.single.contact.id, contact.id);

      await DaoContactRole().reassign(source, target);
      expect((await DaoContactRole().getUsage(source)).isEmpty, isTrue);
      final saved = (await DaoContact().getById(contact.id))!;
      expect(saved.defaultRoleId, target);
      expect(saved.roleDescription, 'Surveyor');
      expect(
        (await DaoContactRole().getUsage(target)).assignments,
        hasLength(1),
      );
      await DaoContactRole().delete(source);
      expect(await DaoContactRole().getById(source), isNull);
    },
  );

  test(
    'duplicate target assignment is combined and legacy fields follow roles',
    () async {
      final job = await makeJob();
      await DaoJobParty().save(
        jobId: job.id,
        contactId: job.contactId!,
        roleId: ContactRole.tenant,
      );
      await DaoContactRole().reassign(ContactRole.primary, ContactRole.tenant);
      final parties = await DaoJobParty().getByJob(job.id);
      expect(
        parties.where((p) => p.role.id == ContactRole.tenant),
        hasLength(1),
      );
      final saved = (await DaoJob().getById(job.id))!;
      expect(saved.contactId, isNull);
      expect(saved.tenantContactId, job.contactId);
      expect(await DaoContactRole().getById(ContactRole.primary), isNotNull);
    },
  );

  test('singleton conflicts roll back earlier jobs and all defaults', () async {
    final first = await makeJob();
    final second = await makeJob();
    final source = await DaoContactRole().create('Coordinator');
    final contact = (await DaoContact().getById(first.contactId))!
      ..defaultRoleId = source;
    await DaoContact().update(contact);
    for (final job in [first, second]) {
      await DaoJobParty().save(
        jobId: job.id,
        contactId: contact.id,
        roleId: source,
      );
    }
    await expectLater(
      DaoContactRole().reassign(source, ContactRole.primary),
      throwsA(
        predicate((error) => error.toString().contains('Job #${second.id}')),
      ),
    );
    expect((await DaoContactRole().getUsage(source)).assignments, hasLength(2));
    expect((await DaoContact().getById(contact.id))!.defaultRoleId, source);
    expect((await DaoJob().getById(second.id))!.contactId, second.contactId);
  });

  test('billing reassignment rejects a contact outside Bill To', () async {
    final job = await makeJob();
    final other = await makeJob();
    final source = await DaoContactRole().create('Accounts liaison');
    await DaoJobParty().save(
      jobId: job.id,
      contactId: other.contactId!,
      roleId: source,
    );
    await expectLater(
      DaoContactRole().reassign(source, ContactRole.billing),
      throwsA(predicate((error) => error.toString().contains('Bill To'))),
    );
    expect((await DaoContactRole().getUsage(source)).assignments, hasLength(1));
    expect(
      (await DaoJob().getById(job.id))!.billingContactId,
      job.billingContactId,
    );
  });

  test(
    'rejects invalid and identical replacement roles without changes',
    () async {
      final role = await DaoContactRole().create('Inspector');
      await expectLater(DaoContactRole().reassign(role, role), throwsException);
      await expectLater(DaoContactRole().reassign(role, -999), throwsException);
      expect(await DaoContactRole().getById(role), isNotNull);
    },
  );
}
