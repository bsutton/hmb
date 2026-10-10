@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_contact_role.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/job_party.dart';
import 'package:hmb/ui/crud/contact/contact_roles_screen.dart';
import 'package:hmb/ui/crud/job/job_parties_screen.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final roleId in [1, 2, 3, 4, 5, 6, 7, 8, 9, -1]) {
    testWidgets(
      'role $roleId selects, saves and reopens another customer contact',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final job = await runAsyncAndPump(
          tester,
          () => createJobWithCustomer(
            billingType: BillingType.timeAndMaterial,
            hourlyRate: MoneyEx.zero,
          ),
        );
        final other = await runAsyncAndPump(
          tester,
          () => createJobWithCustomer(
            billingType: BillingType.timeAndMaterial,
            hourlyRate: MoneyEx.zero,
          ),
        );
        final foreign = (await runAsyncAndPump(
          tester,
          () => DaoContact().getById(other.contactId),
        ))!;
        final owner = (await runAsyncAndPump(
          tester,
          () => DaoCustomer().getById(other.customerId),
        ))!;
        final associated = (await runAsyncAndPump(
          tester,
          () => DaoCustomer().getById(job.customerId),
        ))!;
        await runAsyncAndPump(tester, () async {
          await DaoCustomer().update(
            associated.copyWith(name: 'ZZ Associated'),
          );
          await DaoCustomer().update(owner.copyWith(name: 'AA Other'));
          await DaoContactCustomer().insertJoin(foreign, owner);
        });
        final id = roleId == -1
            ? await runAsyncAndPump(
                tester,
                () => DaoContactRole().create('Inspector'),
              )
            : roleId;
        final role = (await runAsyncAndPump(
          tester,
          () => DaoContactRole().getById(id),
        ))!;
        JobParty? saved;
        final saveCompleted = Completer<void>();
        Future<void> openEditor([JobParty? party]) async {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              initialRoute: '/editor',
              routes: {
                '/': (_) => const Scaffold(),
                '/editor': (_) => JobPartyAssignmentEditor(
                  key: UniqueKey(),
                  customerId: job.customerId,
                  billToCustomerId: job.customerId,
                  relatedCustomerIds: [other.customerId!],
                  parties: const [],
                  party: party,
                  onSave: (contact, role, {required replace}) async {
                    await DaoJobParty().save(
                      jobId: job.id,
                      contactId: contact.id,
                      roleId: role.id,
                      assignmentId: party?.id,
                      replaceSingleton: true,
                    );
                    saved = (await DaoJobParty().getByJob(
                      job.id,
                    )).singleWhere((p) => p.role.id == role.id);
                    saveCompleted.complete();
                  },
                ),
              },
            ),
          );
          await pumpDeferredStates(tester);
        }

        HMBDroplist<int> customers() => tester.widget<HMBDroplist<int>>(
          find.byWidgetPredicate((w) => w is HMBDroplist<int>),
        );
        HMBDroplist<Contact> contacts() => tester.widget<HMBDroplist<Contact>>(
          find.byWidgetPredicate((w) => w is HMBDroplist<Contact>),
        );
        await openEditor();
        final customerIds = await runAsyncAndPump(
          tester,
          () => customers().items(null),
        );
        expect(customerIds.first, job.customerId);
        expect(customerIds, contains(other.customerId));
        expect(customerIds.toSet().length, customerIds.length);
        expect(customers().sortByRecent, isFalse);
        customers().onChanged(other.customerId);
        await pumpDeferredStates(tester);
        final options = await runAsyncAndPump(
          tester,
          () => contacts().items(foreign.bestEmail),
        );
        expect(options.map((c) => c.id), contains(foreign.id));
        contacts().onChanged(foreign);
        await tester.pump();
        tester
            .widget<ContactRoleSelector>(find.byType(ContactRoleSelector))
            .onChanged(role);
        await pumpDeferredStates(tester);
        expect(
          (await runAsyncAndPump(tester, contacts().selectedItem))?.id,
          foreign.id,
        );
        await pumpUntilCondition(
          tester,
          () => tester
              .state<HMBDroplistState<ContactRole>>(
                find.byType(HMBDroplist<ContactRole>),
              )
              .hasSelection,
          'role selection to reach the form',
        );
        await tester.pump();
        final buttons = tester.widget<HMBSaveCancelButtons>(
          find.byType(HMBSaveCancelButtons),
        );
        expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
        buttons.onSave!();
        await runAsyncAndPump(tester, () async {
          await saveCompleted.future;
        });
        await tester.pumpAndSettle();
        expect(saved?.contact.id, foreign.id);
        await openEditor(saved);
        expect(
          await runAsyncAndPump(tester, customers().selectedItem),
          other.customerId,
        );
        expect(
          (await runAsyncAndPump(tester, contacts().selectedItem))?.id,
          foreign.id,
        );
        expect(
          (await runAsyncAndPump(tester, () => customers().items(null))).first,
          job.customerId,
        );
        customers().onChanged(-2);
        await pumpDeferredStates(tester);
        expect(
          (await runAsyncAndPump(
            tester,
            () => contacts().items(foreign.bestEmail),
          )).map((c) => c.id),
          contains(foreign.id),
        );
        customers().onChanged(job.customerId);
        await pumpDeferredStates(tester);
        expect(
          (await runAsyncAndPump(
            tester,
            () => contacts().items(null),
          )).map((c) => c.id),
          contains(job.contactId),
        );
        expect(
          (await runAsyncAndPump(
            tester,
            () => DaoCustomer().getByContact(foreign.id),
          ))?.id,
          other.customerId,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('unavailable associated customer falls back to all customers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobPartyAssignmentEditor(
          customerId: -999,
          billToCustomerId: -999,
          parties: const [],
          onSave: (contact, role, {required replace}) async {},
        ),
      ),
    );
    await pumpDeferredStates(tester);
    final picker = tester.widget<HMBDroplist<int>>(
      find.byWidgetPredicate((w) => w is HMBDroplist<int>),
    );
    final selected = await runAsyncAndPump(tester, picker.selectedItem);
    expect(picker.format(selected!), 'All customers');
    expect(
      await runAsyncAndPump(tester, () => picker.items(null)),
      isNot(contains(-999)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('all related-party customers precede unrelated options', (
    tester,
  ) async {
    final jobs = await runAsyncAndPump(tester, () async {
      final result = <Job>[];
      for (final name in [
        'ZZ Direct',
        'YY Related',
        'XX Related',
        'AA Other',
      ]) {
        final job = await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
        );
        final customer = (await DaoCustomer().getById(job.customerId))!;
        await DaoCustomer().update(customer.copyWith(name: name));
        result.add(job);
      }
      final contact = (await DaoContact().getById(result[1].contactId))!;
      for (final job in result.skip(1).take(2)) {
        await DaoContactCustomer().insertJoin(
          contact,
          (await DaoCustomer().getById(job.customerId))!,
        );
      }
      return result;
    });
    final contact = (await runAsyncAndPump(
      tester,
      () => DaoContact().getById(jobs[1].contactId),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: JobPartyAssignmentEditor(
          customerId: jobs.first.customerId,
          billToCustomerId: jobs.first.customerId,
          relatedCustomerIds: [jobs[1].customerId!, jobs[1].customerId!],
          parties: [
            JobParty(
              id: 1,
              contact: contact,
              role: const ContactRole(
                id: ContactRole.site,
                name: 'Site',
                builtin: true,
              ),
            ),
            JobParty(
              id: 2,
              contact: contact,
              role: const ContactRole(
                id: ContactRole.owner,
                name: 'Owner',
                builtin: true,
              ),
            ),
          ],
          onSave: (contact, role, {required replace}) async {},
        ),
      ),
    );
    await pumpDeferredStates(tester);
    final picker = tester.widget<HMBDroplist<int>>(
      find.byWidgetPredicate((w) => w is HMBDroplist<int>),
    );
    final choices = await runAsyncAndPump(tester, () => picker.items(null));
    expect(choices.take(3), [
      jobs[0].customerId,
      jobs[2].customerId,
      jobs[1].customerId,
    ]);
    expect(choices.skip(3), contains(jobs[3].customerId));
    expect(choices.toSet().length, choices.length);
    expect(
      await runAsyncAndPump(tester, picker.selectedItem),
      jobs[0].customerId,
    );
    expect(await runAsyncAndPump(tester, () => picker.items('AA Other')), [
      jobs[3].customerId,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
