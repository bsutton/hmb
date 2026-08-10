@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/invoicing/invoice_send_button.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(() async {
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  test('invoice email greeting uses invoice billing contact', () async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Invoice greeting job',
    );
    final primaryContact = await DaoContact().getById(job.contactId);
    final billingContactId = await DaoContact().insert(
      Contact.forInsert(
        firstName: 'Bill',
        surname: 'Payer',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: 'bill@example.com',
      ),
    );
    final billingContact = await DaoContact().getById(billingContactId);

    final invoice = Invoice.forInsert(
      jobId: job.id,
      dueDate: LocalDate.today(),
      totalAmount: Money.fromInt(1000, isoCode: 'AUD'),
      billingContactId: billingContactId,
    );

    final greetingContact = await invoiceGreetingContact(
      invoice: invoice,
      job: job,
      primaryContact: primaryContact!,
    );

    expect(greetingContact.id, billingContact!.id);
    expect(greetingContact.firstName, 'Bill');
  });
}
