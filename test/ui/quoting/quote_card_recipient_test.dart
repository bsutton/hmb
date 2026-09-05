@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/quoting/quote_card.dart';
import 'package:hmb/ui/quoting/select_quote_task_photos_dialog.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/select/hmb_select_email_multi.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets(
    'quote recipient selection survives photo options without changing billing',
    (tester) async {
      late Job job;
      late Quote quote;
      late Contact other;
      await tester.runAsync(() async {
        job = await createJobWithCustomer(
          billingType: BillingType.fixedPrice,
          hourlyRate: MoneyEx.dollars(100),
        );
        other = Contact.forInsert(
          firstName: 'Alex',
          surname: 'Recipient',
          mobileNumber: '',
          landLine: '',
          officeNumber: '',
          emailAddress: 'alex@example.com',
        );
        await DaoContact().insert(other);
        await DaoContactCustomer().insertJoin(
          other,
          (await DaoCustomer().getById(job.customerId))!,
        );
        quote = Quote.forInsert(
          jobId: job.id,
          summary: 'Test quote',
          description: '',
          totalAmount: MoneyEx.dollars(100),
        );
        await DaoQuote().insert(quote);
      });
      await tester.pumpWidget(
        ToastificationWrapper(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuoteCard(quote: quote, onStateChanged: (_) {}),
              ),
            ),
          ),
        ),
      );
      await _waitFor(tester, find.text('Send...'));
      await tester.tap(find.text('Send...'));
      await _waitFor(tester, find.byType(HMBDroplist<ContactAndEmail>));
      var field = tester.widget<HMBDroplist<ContactAndEmail>>(
        find.byType(HMBDroplist<ContactAndEmail>),
      );
      final choices = (await tester.runAsync(() => field.items(null)))!;
      final selected = choices.singleWhere(
        (choice) => choice.contact.id == other.id,
      );
      field.onChanged(selected);
      await tester.pump();
      await tester.tap(find.text('Select Task Photos'));
      await _waitFor(tester, find.byType(SelectQuoteTaskPhotosDialog));
      Navigator.of(
        tester.element(find.byType(SelectQuoteTaskPhotosDialog)),
      ).pop();
      await _waitFor(tester, find.byType(HMBDroplist<ContactAndEmail>));
      field = tester.widget<HMBDroplist<ContactAndEmail>>(
        find.byType(HMBDroplist<ContactAndEmail>),
      );
      expect(
        (await tester.runAsync(field.selectedItem))?.email,
        'alex@example.com',
      );
      await tester.runAsync(() async {
        final unchanged = (await DaoJob().getById(job.id))!;
        expect(unchanged.billingContactId, job.billingContactId);
        expect(unchanged.contactId, job.contactId);
      });
      await tester.tap(find.text('Cancel'));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    },
  );
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(finder, findsWidgets);
}
