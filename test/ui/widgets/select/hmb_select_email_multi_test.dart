@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/select/hmb_select_email_multi.dart';
import 'package:hmb/util/dart/money_ex.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test(
    'fromJob includes customer contacts and dedupes alternate email',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      final customer = (await DaoCustomer().getById(job.customerId))!;
      final contact = Contact.forInsert(
        firstName: 'Bill',
        surname: 'Payer',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: 'billing@example.com',
        alternateEmail: ' Billing@Example.com ',
      );
      final contactId = await DaoContact().insert(contact);
      final insertedContact = (await DaoContact().getById(contactId))!;
      await DaoContactCustomer().insertJoin(insertedContact, customer);

      final emails = await ContactAndEmail.fromJob(job, null);

      expect(
        emails.map((contactAndEmail) => contactAndEmail.email),
        contains('billing@example.com'),
      );
      expect(
        emails
            .where(
              (contactAndEmail) =>
                  contactAndEmail.email.trim().toLowerCase() ==
                  'billing@example.com',
            )
            .length,
        1,
      );
    },
  );
}
