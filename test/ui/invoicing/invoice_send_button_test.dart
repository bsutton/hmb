@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/dialog/email_dialog_for_job.dart';
import 'package:hmb/ui/invoicing/invoice_send_button.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist_multi.dart';
import 'package:hmb/ui/widgets/select/hmb_select_email_multi.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
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
      primaryContact: primaryContact,
    );

    expect(greetingContact!.id, billingContact!.id);
    expect(greetingContact.firstName, 'Bill');
  });
  test(
    'cross-customer billing recipient is selectable and greeting agrees',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Client job',
      );
      final otherJob = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Billing account',
      );
      final billing = (await DaoContact().getById(otherJob.contactId))!;
      final primary = (await DaoContact().getById(job.contactId))!;
      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: MoneyEx.dollars(100),
        billingContactId: billing.id,
      );
      final greeting = await invoiceGreetingContact(
        invoice: invoice,
        job: job,
        primaryContact: primary,
      );
      expect(greeting!.id, billing.id);
      final selectable = await ContactAndEmail.fromJob(
        job,
        null,
        additionalContacts: [billing],
      );
      expect(
        selectable.where((item) => item.contact.id == billing.id),
        isNotEmpty,
      );
      expect(
        invoiceEmailBody(invoice: invoice, recipients: [greeting]),
        startsWith('${billing.firstName.trim()},'),
      );
    },
  );

  test(
    'fallback and missing names never substitute an unrelated greeting',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Fallback job',
      );
      final primary = (await DaoContact().getById(job.contactId))!;
      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: MoneyEx.zero,
        billingContactId: null,
      );
      expect(
        (await invoiceGreetingContact(
          invoice: invoice,
          job: job,
          primaryContact: primary,
        ))!.id,
        primary.id,
      );
      final nameless = Contact.forInsert(
        firstName: '',
        surname: '',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: 'bill@example.com',
      );
      expect(
        invoiceEmailBody(invoice: invoice, recipients: [nameless]),
        startsWith('Hello,'),
      );
      expect(
        invoiceEmailBody(invoice: invoice, recipients: []),
        startsWith('Hello,'),
      );
      final surnameOnly = Contact.forInsert(
        firstName: '',
        surname: 'Accounts',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: '',
      );
      expect(
        invoiceEmailBody(invoice: invoice, recipients: [surnameOnly]),
        startsWith('Accounts,'),
      );
    },
  );

  test(
    'missing billing email does not substitute the primary contact',
    () async {
      final job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Missing email',
      );
      final primary = (await DaoContact().getById(job.contactId))!;
      final billing = Contact.forInsert(
        firstName: 'Bill',
        surname: 'Noemail',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: '',
      );
      await DaoContact().insert(billing);
      final invoice = Invoice.forInsert(
        jobId: job.id,
        dueDate: LocalDate.today(),
        totalAmount: MoneyEx.zero,
        billingContactId: billing.id,
      );
      expect(
        (await invoiceGreetingContact(
          invoice: invoice,
          job: job,
          primaryContact: primary,
        ))!.id,
        billing.id,
      );
      final choices = await ContactAndEmail.fromJob(
        job,
        null,
        additionalContacts: [billing],
      );
      expect(choices.where((item) => item.contact.id == billing.id), isEmpty);
      invoice.billingContactId = null;
      job
        ..billingContactId = null
        ..legacyBillingContactId = null
        ..contactId = null
        ..billToCustomerId = -99999;
      expect(
        await invoiceGreetingContact(
          invoice: invoice,
          job: job,
          primaryContact: null,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'recipient changes update generated greeting but preserve edited text',
    (tester) async {
      final fixture = (await tester.runAsync(() async {
        final job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          summary: 'Composer job',
        );
        final primary = (await DaoContact().getById(job.contactId))!;
        final billing = Contact.forInsert(
          firstName: 'Billing',
          surname: 'Person',
          mobileNumber: '',
          landLine: '',
          officeNumber: '',
          emailAddress: 'billing@example.com',
        );
        await DaoContact().insert(billing);
        final invoice = Invoice.forInsert(
          jobId: job.id,
          dueDate: LocalDate.today(),
          totalAmount: MoneyEx.zero,
          billingContactId: billing.id,
        );
        final options = await ContactAndEmail.fromJob(
          job,
          null,
          additionalContacts: [billing],
        );
        return (job, primary, billing, invoice, options);
      }))!;
      final (job, primary, billing, invoice, options) = fixture;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmailDialogForJob(
              job: job,
              additionalContacts: [billing],
              preferredRecipient: billing.bestEmail,
              subject: 'Custom subject',
              body: invoiceEmailBody(invoice: invoice, recipients: [billing]),
              bodyForContacts: (contacts) =>
                  invoiceEmailBody(invoice: invoice, recipients: contacts),
              attachmentPaths: const [],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final body = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Body',
      );
      final subject = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Subject',
      );
      expect(
        tester.widget<TextField>(body).controller!.text,
        startsWith('Billing,'),
      );
      final dropdown = find.byType(HMBDroplistMultiSelect<ContactAndEmail>);
      for (
        var attempt = 0;
        attempt < 20 && dropdown.evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pumpAndSettle();
      }
      expect(dropdown, findsOneWidget);
      tester
          .widget<HMBDroplistMultiSelect<ContactAndEmail>>(dropdown)
          .onChanged([
            options.firstWhere((item) => item.contact.id == primary.id),
          ]);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<HMBDroplistMultiSelectState<ContactAndEmail>>(dropdown)
            .selectedItems
            .single
            .contact
            .id,
        primary.id,
      );
      expect(
        tester
            .widget<HMBSelectEmailMulti>(find.byType(HMBSelectEmailMulti))
            .initialEmails,
        [primary.bestEmail],
      );
      expect(
        tester.widget<TextField>(body).controller!.text,
        startsWith('${primary.firstName.trim()},'),
      );
      await tester.enterText(
        body,
        'My custom greeting and edited invoice message.',
      );
      tester
          .widget<HMBDroplistMultiSelect<ContactAndEmail>>(dropdown)
          .onChanged([
            options.firstWhere((item) => item.contact.id == billing.id),
          ]);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<HMBDroplistMultiSelectState<ContactAndEmail>>(dropdown)
            .selectedItems
            .single
            .contact
            .id,
        billing.id,
      );
      expect(
        tester
            .widget<HMBSelectEmailMulti>(find.byType(HMBSelectEmailMulti))
            .initialEmails,
        [billing.bestEmail],
      );
      expect(
        tester.widget<TextField>(body).controller!.text,
        'My custom greeting and edited invoice message.',
      );
      expect(
        tester.widget<TextField>(subject).controller!.text,
        'Custom subject',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
