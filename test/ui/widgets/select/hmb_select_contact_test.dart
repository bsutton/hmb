import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/select/hmb_select_contact.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  test('contact selection includes the role when requested', () {
    final contact = Contact.forInsert(
      firstName: 'Alex',
      surname: 'Smith',
      mobileNumber: '',
      landLine: '',
      officeNumber: '',
      emailAddress: 'alex@example.com',
      roleDescription: 'Body corporate manager',
    );

    expect(
      formatContactForSelection(contact, showRole: true),
      'Alex Smith — Body corporate manager',
    );
    expect(formatContactForSelection(contact), 'Alex Smith');
  });
  for (final allowOthers in [false, true]) {
    testWidgets('contact selector cross-customer mode: $allowOthers', (
      tester,
    ) async {
      await runAsyncAndPump(tester, setupTestDb);
      addTearDown(tearDownTestDb);
      final jobs = await runAsyncAndPump(tester, () async {
        final result = <Job>[];
        for (var i = 0; i < 2; i++) {
          final job = await createJobWithCustomer(
            billingType: BillingType.timeAndMaterial,
            hourlyRate: MoneyEx.zero,
          );
          await DaoContactCustomer().insertJoin(
            (await DaoContact().getById(job.contactId))!,
            (await DaoCustomer().getById(job.customerId))!,
          );
          result.add(job);
        }
        return result;
      });
      final customer = await runAsyncAndPump(
        tester,
        () => DaoCustomer().getById(jobs.first.customerId),
      );
      final foreign = (await runAsyncAndPump(
        tester,
        () => DaoContact().getById(jobs.last.contactId),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HMBSelectContact(
              customer: customer,
              initialContact: foreign.id,
              allowOtherCustomers: allowOthers,
            ),
          ),
        ),
      );
      await pumpDeferredStates(tester);
      final picker = tester.widget<HMBDroplist<Contact>>(
        find.byType(HMBDroplist<Contact>),
      );
      final choices = await runAsyncAndPump(tester, () => picker.items(null));
      expect(choices.any((c) => c.id == jobs.first.contactId), isTrue);
      expect(choices.any((c) => c.id == foreign.id), allowOthers);
      expect(
        (await runAsyncAndPump(tester, picker.selectedItem))?.id,
        foreign.id,
      );
      expect(
        (await runAsyncAndPump(
          tester,
          () => picker.items(foreign.bestEmail),
        )).any((c) => c.id == foreign.id),
        allowOthers,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
