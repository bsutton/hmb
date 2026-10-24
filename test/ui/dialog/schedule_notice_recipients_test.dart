@Tags(['flutter'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_contact_role.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/dialog/send_notice_for_job_dialog.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist_multi.dart';
import 'package:hmb/ui/widgets/select/hmb_select_email_multi.dart';
import 'package:hmb/ui/widgets/select/hmb_select_mobile_multi.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  Future<Job> seed() async {
    final job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
    );
    final customRole = await DaoContactRole().create('Inspector');
    for (final (name, mobile, role) in [
      ('Tenant', '0411 111 111', ContactRole.tenant),
      ('Inspector', '0422222222', customRole),
      ('Shared mobile', '0411111111', ContactRole.owner),
      ('Email only', '', ContactRole.site),
    ]) {
      final contact = Contact.forInsert(
        firstName: name,
        surname: 'Example',
        mobileNumber: mobile,
        landLine: '',
        officeNumber: '',
        emailAddress: '${name.replaceAll(' ', '')}@example.com',
      );
      await DaoContact().insert(contact);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: contact.id,
        roleId: role,
      );
      if (name == 'Inspector') {
        await DaoJobParty().save(
          jobId: job.id,
          contactId: contact.id,
          roleId: ContactRole.authoriser,
        );
      }
    }
    await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.zero,
      summary: 'Unrelated job',
    );
    return job;
  }

  test(
    'job recipients include every party once and exclude other jobs',
    () async {
      final job = await seed();
      final contacts = await DaoContact().getByJob(job.id);
      expect(contacts, hasLength(5));
      expect(contacts.map((c) => c.id).toSet(), hasLength(5));
      expect(
        contacts.map((c) => c.firstName),
        containsAll(['Tenant', 'Inspector']),
      );
      final mobiles = await ContactAndMobile.fromJob(job, null);
      expect(
        mobiles.map((c) => c.mobile),
        unorderedEquals(['0400000000', '0411111111', '0422222222']),
      );
      expect(
        (await ContactAndMobile.fromJob(job, 'Inspector')).single.mobile,
        '0422222222',
      );
      final emails = await ContactAndEmail.fromJob(job, 'example.com');
      expect(
        emails.map((c) => c.email),
        containsAll([
          'Tenant@example.com',
          'Inspector@example.com',
          'Emailonly@example.com',
        ]),
      );
      expect(
        emails.where((c) => c.email == 'Inspector@example.com'),
        hasLength(1),
      );
    },
  );

  for (final count in [0, 1, 2]) {
    testWidgets('SMS hands off only $count selected parties after rebuilding', (
      tester,
    ) async {
      final job = await runAsyncAndPump(tester, seed);
      final launched = <Uri>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => ToastificationWrapper(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => SendNoticeForJobDialog.show(
                  context,
                  job,
                  JobActivity.forInsert(
                    jobId: job.id,
                    start: DateTime(2099, 1, 1, 9),
                    end: DateTime(2099, 1, 1, 10),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await pumpDeferredStates(tester);
      final picker = find.byType(HMBDroplistMultiSelect<ContactAndMobile>);
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await pumpUntilFound(tester, find.text('Inspector Example\n0422222222'));
      // Remove the default contact before selecting one or several parties.
      await tester.tap(find.text('Pat Tester\n0400000000'));
      if (count >= 1) {
        await tester.tap(find.text('Tenant Example\n0411111111'));
      }
      if (count == 2) {
        await tester.tap(find.text('Inspector Example\n0422222222'));
      }
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      final state = tester.state<HMBDroplistMultiSelectState<ContactAndMobile>>(
        picker,
      );
      expect(state.selectedItems, hasLength(count));
      // Reopen to verify the parent rebuild did not restore the default.
      await tester.tap(picker);
      await pumpUntilFound(tester, find.text('Inspector Example\n0422222222'));
      expect(
        tester
            .widget<ListTile>(
              find.ancestor(
                of: find.text('Pat Tester\n0400000000'),
                matching: find.byType(ListTile),
              ),
            )
            .selected,
        isFalse,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send...'));
      if (count == 0) {
        await tester.pumpAndSettle();
        expect(launched, isEmpty);
        expect(find.byType(SendNoticeForJobDialog), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 7));
      } else {
        await pumpUntilCondition(
          tester,
          () => launched.isNotEmpty,
          'SMS handoff',
        );
        expect(
          launched.single.path.split(RegExp('[,;]')),
          unorderedEquals(['0411111111', if (count == 2) '0422222222']),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
