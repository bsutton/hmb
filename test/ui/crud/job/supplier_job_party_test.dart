import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_contact_role.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/job_party.dart';
import 'package:hmb/ui/crud/contact/contact_roles_screen.dart';
import 'package:hmb/ui/crud/contact/edit_contact_screen.dart';
import 'package:hmb/ui/crud/job/job_parties_screen.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  testWidgets('supplier contact saves and reopens without a customer record', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Job job;
    late Supplier supplier;
    late Contact contact;
    late int customerCount;
    await runAsyncAndPump(tester, () async {
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
      );
      supplier = await _supplier();
      contact = Contact.forInsert(
        firstName: 'Pat',
        surname: 'Supplier',
        mobileNumber: '',
        landLine: '',
        officeNumber: '',
        emailAddress: 'pat@example.com',
        defaultRoleId: ContactRole.projectManager,
      );
      await DaoContact().insert(contact);
      await DaoContactSupplier().insertJoin(contact, supplier);
      customerCount = (await DaoCustomer().getAll()).length;
    });
    JobParty? saved;
    final completed = Completer<void>();
    Future<void> openEditor([JobParty? party]) async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          initialRoute: '/editor',
          routes: {
            '/': (_) => const Scaffold(),
            '/editor': (_) => JobPartyAssignmentEditor(
              customerId: job.customerId,
              billToCustomerId: job.billingCustomerId,
              parties: const [],
              party: party,
              onSave: (selected, role, {required replace}) async {
                await DaoJobParty().save(
                  jobId: job.id,
                  contactId: selected.id,
                  roleId: role.id,
                  assignmentId: party?.id,
                  replaceSingleton: replace,
                );
                saved = (await DaoJobParty().getByJob(
                  job.id,
                )).singleWhere((p) => p.contact.id == selected.id);
                completed.complete();
              },
            ),
          },
        ),
      );
      await pumpDeferredStates(tester);
    }

    HMBDroplist<JobPartyContactSource> source() =>
        tester.widget(find.byType(HMBDroplist<JobPartyContactSource>));
    HMBDroplist<Supplier> suppliers() =>
        tester.widget(find.byType(HMBDroplist<Supplier>));
    HMBDroplist<Contact> contacts() =>
        tester.widget(find.byType(HMBDroplist<Contact>));

    await openEditor();
    source().onChanged(JobPartyContactSource.supplier);
    await pumpDeferredStates(tester);
    expect(
      await runAsyncAndPump(tester, () => contacts().items(null)),
      isEmpty,
    );
    expect(contacts().onAdd, isNull);
    expect(
      (await runAsyncAndPump(
        tester,
        () => suppliers().items('Trade Supplies'),
      )).map((s) => s.id),
      contains(supplier.id),
    );
    suppliers().onChanged(supplier);
    await pumpDeferredStates(tester);
    final options = await runAsyncAndPump(
      tester,
      () => contacts().items('pat@example.com'),
    );
    expect(options.map((c) => c.id), [contact.id]);
    contacts().onChanged(contact);
    await pumpDeferredStates(tester);
    final role = (await runAsyncAndPump(
      tester,
      () => DaoContactRole().getById(ContactRole.projectManager),
    ))!;
    tester
        .widget<ContactRoleSelector>(find.byType(ContactRoleSelector))
        .onChanged(role);
    await pumpDeferredStates(tester);
    await pumpUntilCondition(
      tester,
      () => tester
          .state<HMBDroplistState<ContactRole>>(
            find.byType(HMBDroplist<ContactRole>),
          )
          .hasSelection,
      'selected role',
    );
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    tester
        .widget<HMBSaveCancelButtons>(find.byType(HMBSaveCancelButtons))
        .onSave!();
    await runAsyncAndPump(tester, () => completed.future);
    await tester.pumpAndSettle();
    await openEditor(saved);
    expect(
      await runAsyncAndPump(tester, source().selectedItem),
      JobPartyContactSource.supplier,
    );
    expect(
      (await runAsyncAndPump(tester, suppliers().selectedItem))?.id,
      supplier.id,
    );
    expect(
      (await runAsyncAndPump(tester, contacts().selectedItem))?.id,
      contact.id,
    );
    source().onChanged(JobPartyContactSource.customer);
    await pumpDeferredStates(tester);
    expect(await runAsyncAndPump(tester, contacts().selectedItem), isNull);
    expect(
      (await runAsyncAndPump(
        tester,
        () => contacts().items(null),
      )).map((c) => c.id),
      contains(job.contactId),
    );
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: JobPartiesScreen(job: job, editCustomers: () async {}),
      ),
    );
    await pumpDeferredStates(tester);
    await pumpReadOnlyFutureBuilders(tester, find.byType(JobPartiesScreen));
    expect(find.text('Pat Supplier'), findsOneWidget);
    expect(find.textContaining('Supplier: Trade Supplies'), findsOneWidget);
    await runAsyncAndPump(tester, () async {
      expect((await DaoCustomer().getAll()).length, customerCount);
      expect(await DaoCustomer().getByContact(contact.id), isNull);
      expect(
        (await DaoSupplier().getByContact(contact.id)).single.id,
        supplier.id,
      );
      final storedJob = (await DaoJob().getById(job.id))!;
      expect(storedJob.customerId, job.customerId);
      expect(storedJob.billingCustomerId, job.billingCustomerId);
      expect(storedJob.billingContactId, job.billingContactId);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('supplier without contacts opens supplier contact creation', (
    tester,
  ) async {
    final supplier = await runAsyncAndPump(tester, _supplier);
    var customerCreatorCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: JobPartyAssignmentEditor(
          customerId: null,
          billToCustomerId: null,
          parties: const [],
          createContact: ({required billing, required customerId}) async {
            customerCreatorCalled = true;
            return null;
          },
          onSave: (contact, role, {required replace}) async {},
        ),
      ),
    );
    await pumpDeferredStates(tester);
    tester
        .widget<HMBDroplist<JobPartyContactSource>>(
          find.byType(HMBDroplist<JobPartyContactSource>),
        )
        .onChanged(JobPartyContactSource.supplier);
    await pumpDeferredStates(tester);
    tester
        .widget<HMBDroplist<Supplier>>(find.byType(HMBDroplist<Supplier>))
        .onChanged(supplier);
    await pumpDeferredStates(tester);
    final contacts = tester.widget<HMBDroplist<Contact>>(
      find.byType(HMBDroplist<Contact>),
    );
    expect(await runAsyncAndPump(tester, () => contacts.items(null)), isEmpty);
    unawaited(contacts.onAdd!());
    await pumpUntilFound(tester, find.byType(ContactEditScreen<Supplier>));
    await pumpDeferredStates(tester);
    expect(
      tester
          .widget<ContactEditScreen<Supplier>>(
            find.byType(ContactEditScreen<Supplier>),
          )
          .parent
          .id,
      supplier.id,
    );
    expect(customerCreatorCalled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<Supplier> _supplier() async {
  final supplier = Supplier.forInsert(
    name: 'Trade Supplies',
    businessNumber: null,
    description: null,
    bsb: null,
    accountNumber: null,
    service: null,
  );
  await DaoSupplier().insert(supplier);
  return supplier;
}
