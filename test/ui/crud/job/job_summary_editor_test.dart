@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_contact_role.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/contact/contact_roles_screen.dart';
import 'package:hmb/ui/crud/job/edit_job_screen.dart';
import 'package:hmb/ui/crud/job/job_edit_section.dart';
import 'package:hmb/ui/crud/job/job_parties_screen.dart';
import 'package:hmb/ui/crud/job/job_summary_card.dart';
import 'package:hmb/ui/crud/job/mini_job_dashboard.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  Future<Job> seed(WidgetTester tester) async {
    late Job job;
    await tester.runAsync(() async {
      await setupTestDb();
      job = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(95),
      );
    });
    addTearDown(tearDownTestDb);
    return job;
  }

  Future<void> showEditor(WidgetTester tester, Job job) => tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => Stack(children: [child!, const BlockingOverlay()]),
      home: JobEditScreen(job: job),
    ),
  );

  for (final section in [null, JobEditSection.summary]) {
    testWidgets('job ${section?.name ?? 'overview'} paints while loading', (
      tester,
    ) async {
      final job = await seed(tester);
      late Completer<void> release;
      late Future<void> blocker;
      await tester.runAsync(() async {
        final acquired = Completer<void>();
        release = Completer<void>();
        blocker = testDb!.transaction((_) async {
          acquired.complete();
          await release.future;
        });
        await acquired.future;
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: HMBTheme.dark,
            builder: (_, child) =>
                Stack(children: [child!, const BlockingOverlay()]),
            home: JobEditScreen(job: job, section: section),
          ),
        );
        // Initialization is deliberately blocked: the route still needs to
        // paint its own themed surface and navigation, even before data loads.
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.color == HMBColors.defaultBackground,
          ),
          findsWidgets,
        );
      } finally {
        release.complete();
        await tester.runAsync(() => blocker);
        await pumpUntil(
          tester,
          section == null
              ? find.byType(JobSummaryCard)
              : find.byType(TextFormField),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final section in [
    JobEditSection.summary,
    JobEditSection.internalNotes,
    JobEditSection.assumptions,
  ]) {
    testWidgets('${section.name} fills the screen and resizes for keyboard', (
      tester,
    ) async {
      final job = await seed(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: HMBTheme.dark,
          builder: (_, child) =>
              Stack(children: [child!, const BlockingOverlay()]),
          home: JobEditScreen(job: job, section: section),
        ),
      );
      await pumpUntil(tester, find.byType(TextFormField));
      final field = find.byType(TextFormField).last;
      expect(tester.getSize(field).height, greaterThan(500));
      expect(tester.getRect(field).bottom, closeTo(784, 1));
      await tester.enterText(field, 'Keep this text while resizing.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getSize(field).height, greaterThan(150));
      expect(tester.getRect(field).bottom, closeTo(484, 1));
      expect(find.text('Keep this text while resizing.'), findsOneWidget);
      tester.view.physicalSize = const Size(800, 360);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('returning from a section retains the job scroll offset', (
    tester,
  ) async {
    final job = await seed(tester);
    await showEditor(tester, job);
    await pumpUntil(tester, find.byType(JobSummaryCard));
    final edit = find.byKey(const ValueKey('edit-job-section-assumptions'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final offset = scroll.position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(edit);
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.tap(find.text('Cancel'));
    await pumpUntil(tester, find.byType(JobSummaryCard));
    expect(scroll.position.pixels, closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'job note dialog fills its space and saves after keyboard resize',
    (tester) async {
      final job = await seed(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await showEditor(tester, job);
      await pumpUntil(tester, find.byType(JobSummaryCard));
      final edit = find.byKey(const ValueKey('edit-job-section-notes'));
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = scroll.position.pixels;
      await tester.tap(edit);
      await pumpUntil(tester, find.text('No notes'));
      await tester.tap(find.byTooltip('Add a job note.'));
      await pumpUntil(tester, find.byType(TextFormField));
      final field = find.byType(TextFormField);
      expect(tester.getSize(field).height, greaterThan(400));
      await tester.enterText(field, 'A saved job note.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getSize(field).height, greaterThan(200));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      tester.view.resetViewInsets();
      await pumpUntil(tester, find.text('A saved job note.'));
      await tester.pageBack();
      await pumpUntil(tester, find.text('1 note(s)'));
      expect(scroll.position.pixels, closeTo(offset, 1));
      await tester.runAsync(() async {
        final notes = await DaoActivity().getByJob(
          job.id,
          type: ActivityType.note,
        );
        expect(notes.single.details, 'A saved job note.');
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('business referral is a removable party, not a customer field', (
    tester,
  ) async {
    final job = await seed(tester);
    await tester.runAsync(() async {
      await DaoJob().setReferringCustomer(job.id, job.customerId);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: JobPartiesScreen(job: job, editCustomers: () async {}),
      ),
    );
    await pumpUntil(tester, find.text('Referrer · Customer/business'));
    expect(find.textContaining('Referred by:'), findsNothing);
    await tester.tap(find.byTooltip('Remove referring business'));
    await pumpUntil(tester, find.text('Remove referring business?'));
    await tester.tap(find.text('Remove'));
    await pumpUntil(tester, find.text('Add referring business'));
    await tester.runAsync(() async {
      final saved = (await DaoJob().getById(job.id))!;
      expect(saved.referrerCustomerId, isNull);
      expect(saved.customerId, job.customerId);
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: JobEditScreen(job: job, section: JobEditSection.customer),
      ),
    );
    await pumpUntil(tester, find.byType(HMBDroplist<Customer>));
    expect(find.byType(HMBDroplist<Customer>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'party defaults are suggestions and Cancel creates no assignment',
    (tester) async {
      final job = await seed(tester);
      late Contact contact;
      await tester.runAsync(() async {
        contact = (await DaoContact().getById(job.contactId))!
          ..defaultRoleId = ContactRole.owner;
        await DaoContact().update(contact);
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              Stack(children: [child!, const BlockingOverlay()]),
          home: JobPartiesScreen(job: job, editCustomers: () async {}),
        ),
      );
      await pumpUntil(tester, find.text('Add party'));
      await tester.tap(find.text('Add party'));
      await pumpUntil(tester, find.byType(ContactRoleSelector));
      tester
          .widget<HMBDroplist<Contact>>(find.byType(HMBDroplist<Contact>))
          .onChanged(contact);
      await pumpUntil(tester, find.text('Owner'));
      expect(
        tester
            .widget<ContactRoleSelector>(find.byType(ContactRoleSelector))
            .roleId,
        ContactRole.owner,
      );
      await tester.tap(find.text('Cancel'));
      await pumpUntil(tester, find.text('Add party'));
      await tester.runAsync(() async {
        expect(await DaoJobParty().getByJob(job.id), hasLength(2));
        expect(
          (await DaoContact().getById(contact.id))!.defaultRoleId,
          ContactRole.owner,
        );
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('party customer filter defaults and ranks related customers', (
    tester,
  ) async {
    final job = await seed(tester);
    late Job related;
    late Job unrelated;
    await tester.runAsync(() async {
      related = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Related account',
      );
      unrelated = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Unrelated account',
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: JobPartyAssignmentEditor(
          customerId: job.customerId,
          billToCustomerId: job.customerId,
          relatedCustomerIds: [related.customerId!],
          parties: const [],
          onSave: (contact, role, {required replace}) async {},
        ),
      ),
    );
    await pumpUntil(tester, find.byType(ContactRoleSelector));
    final filter = tester.widget<HMBDroplist<int>>(
      find.byType(HMBDroplist<int>),
    );
    await tester.runAsync(() async {
      expect(await filter.selectedItem(), job.customerId);
      final customers = await filter.items(null);
      expect(
        customers.indexOf(related.customerId!),
        lessThan(customers.indexOf(unrelated.customerId!)),
      );
      final contacts = await tester
          .widget<HMBDroplist<Contact>>(find.byType(HMBDroplist<Contact>))
          .items(null);
      expect(contacts.map((contact) => contact.id), contains(job.contactId));
      expect(
        contacts.map((contact) => contact.id),
        isNot(contains(related.contactId)),
      );
    });
    filter.onChanged(related.customerId);
    await tester.pump();
    await tester.runAsync(() async {
      final contacts = await tester
          .widget<HMBDroplist<Contact>>(find.byType(HMBDroplist<Contact>))
          .items(null);
      expect(
        contacts.map((contact) => contact.id),
        contains(related.contactId),
      );
      expect(
        contacts.map((contact) => contact.id),
        isNot(contains(job.contactId)),
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('role usage reviews and reassigns contacts and jobs', (
    tester,
  ) async {
    final job = await seed(tester);
    late int source;
    await tester.runAsync(() async {
      source = await DaoContactRole().create('Old dispatch');
      final contact = (await DaoContact().getById(job.contactId))!
        ..defaultRoleId = source;
      await DaoContact().update(contact);
      await DaoJobParty().save(
        jobId: job.id,
        contactId: contact.id,
        roleId: source,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => ToastificationWrapper(
          child: Stack(children: [child!, const BlockingOverlay()]),
        ),
        home: const ContactRolesScreen(),
      ),
    );
    await pumpUntil(tester, find.text('Add role type'));
    await tester.scrollUntilVisible(find.text('Old dispatch'), 200);
    await tester.tap(find.text('Old dispatch'));
    await pumpUntil(
      tester,
      find.text('Contact defaults: 1 · Job assignments: 1'),
    );
    expect(find.text('Contacts using this default role'), findsOneWidget);
    final picker = tester.widget<ContactRoleSelector>(
      find.byType(ContactRoleSelector),
    );
    expect(picker.excludeRoleId, source);
    picker.onChanged(
      const ContactRole(
        id: ContactRole.site,
        name: 'Site Contact',
        builtin: true,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Reassign all uses'));
    await pumpUntil(tester, find.text('Reassign all uses?'));
    await tester.tap(find.text('Reassign'));
    await pumpUntil(
      tester,
      find.text('Contact defaults: 0 · Job assignments: 0'),
    );
    await tester.runAsync(() async {
      expect(
        (await DaoContact().getById(job.contactId))!.defaultRoleId,
        ContactRole.site,
      );
      expect((await DaoContactRole().getUsage(source)).isEmpty, isTrue);
    });
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('role selector creates and selects a custom role', (
    tester,
  ) async {
    await seed(tester);
    ContactRole? selected;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: Scaffold(
          body: ContactRoleSelector(
            roleId: null,
            title: 'Role on this job',
            onChanged: (role) => selected = role,
          ),
        ),
      ),
    );
    await pumpUntil(tester, find.text('Add role'));
    await tester.tap(find.text('Add role'));
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Access coordinator');
    await tester.tap(find.text('Save'));
    await pumpUntil(tester, find.text('Access coordinator'));
    expect(selected?.name, 'Access coordinator');
    expect(selected?.builtin, isFalse);
    expect(selected?.id, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom role dialog saves without controller disposal errors', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: const ContactRolesScreen(),
      ),
    );
    await pumpUntil(tester, find.text('Add role type'));
    await tester.tap(find.text('Add role type'));
    await pumpUntil(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Inspection contact');
    await tester.tap(find.text('Save'));
    await pumpUntil(tester, find.text('Add role type'));
    await tester.scrollUntilVisible(find.text('Inspection contact'), 200);
    await pumpUntil(tester, find.text('Inspection contact'));
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing the site stays cleared when saving the site editor', (
    tester,
  ) async {
    final job = await seed(tester);
    await showEditor(tester, job);
    await pumpUntil(tester, find.text('Job actions'));
    final edit = find.byKey(const ValueKey('edit-job-section-site'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await pumpUntil(tester, find.byType(HMBDroplist<Site>));
    tester
        .widget<HMBDroplist<Site>>(find.byType(HMBDroplist<Site>))
        .onChanged(null);
    await pumpUntil(tester, find.text('Select a Site'));
    await tester.tap(find.text('Save'));
    await pumpUntil(tester, find.text('No site selected'));
    await tester.runAsync(() async {
      expect((await DaoJob().getById(job.id))!.siteId, isNull);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'summary has roles and actions, without edit fields or dashlets',
    (tester) async {
      final job = await seed(tester);
      await tester.runAsync(
        () => DaoJobParty().save(
          jobId: job.id,
          contactId: job.contactId!,
          roleId: ContactRole.owner,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await showEditor(tester, job);
      await pumpUntil(tester, find.text('Job actions'));
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(MiniJobDashboard), findsNothing);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Primary Contact'), findsOneWidget);
      expect(find.text('Billing Contact'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Send invoices to'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summary Cancel discards, Save preserves unrelated newer fields',
    (tester) async {
      final job = await seed(tester);
      await showEditor(tester, job);
      await pumpUntil(tester, find.text('Job actions'));
      final edit = find.byKey(const ValueKey('edit-job-section-summary'));
      await tester.tap(edit);
      await pumpUntil(tester, find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField).first, 'Discard this');
      await tester.tap(find.text('Cancel'));
      await pumpUntil(tester, find.text('Job actions'));
      await tester.runAsync(() async {
        expect((await DaoJob().getById(job.id))!.summary, 'Test Job');
      });
      await tester.tap(edit);
      await pumpUntil(tester, find.byType(TextFormField));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Updated summary',
      );
      await tester.runAsync(() async {
        final latest = (await DaoJob().getById(job.id))!
          ..internalNotes = 'Newer notes';
        await DaoJob().update(latest);
      });
      await tester.tap(find.text('Save'));
      await pumpUntil(tester, find.text('Job actions'));
      await tester.runAsync(() async {
        final saved = (await DaoJob().getById(job.id))!;
        expect(saved.summary, 'Updated summary');
        expect(saved.internalNotes, 'Newer notes');
        expect(saved.status, job.status);
        expect(await DaoJobParty().getByJob(job.id), hasLength(2));
      });
      expect(find.byType(JobSummaryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('billing contacts follow the Bill To customer', (tester) async {
    final job = await seed(tester);
    late Job other;
    late Customer otherCustomer;
    await tester.runAsync(() async {
      other = await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.dollars(95),
      );
      otherCustomer = (await DaoCustomer().getById(other.customerId))!;
    });
    await showEditor(tester, job);
    await pumpUntil(tester, find.text('Job actions'));
    final editBilling = find.byKey(const ValueKey('edit-job-section-billing'));
    await tester.ensureVisible(editBilling);
    await tester.tap(editBilling);
    await pumpUntil(tester, find.text('Bill To customer'));
    final billTo = tester.widget<HMBDroplist<Customer>>(
      find.byType(HMBDroplist<Customer>),
    );
    var contacts = tester.widget<HMBDroplist<Contact>>(
      find.byType(HMBDroplist<Contact>),
    );
    await tester.runAsync(() async {
      expect((await billTo.selectedItem())!.id, job.customerId);
      expect((await contacts.items(null)).map((c) => c.id), [job.contactId]);
    });
    billTo.onChanged(otherCustomer);
    await pumpUntil(
      tester,
      find.byKey(ValueKey('billing-contact-${other.customerId}')),
    );
    contacts = tester.widget<HMBDroplist<Contact>>(
      find.byType(HMBDroplist<Contact>),
    );
    await tester.runAsync(() async {
      expect(await contacts.selectedItem(), isNull);
      expect((await contacts.items(null)).map((c) => c.id), [other.contactId]);
    });
    final selected = await tester.runAsync(
      () => DaoContact().getById(other.contactId),
    );
    contacts.onChanged(selected);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await pumpUntil(tester, find.text('Job actions'));
    await tester.runAsync(() async {
      final saved = (await DaoJob().getById(job.id))!;
      expect(saved.customerId, job.customerId);
      expect(saved.billingCustomerId, other.customerId);
      expect(saved.billingContactId, other.contactId);
      final billing = (await DaoJobParty().getByJob(
        job.id,
      )).singleWhere((party) => party.role.id == ContactRole.billing);
      expect(billing.contact.id, other.contactId);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('billing summary shows mixed task overrides and job default', (
    tester,
  ) async {
    final job = await seed(tester);
    await tester.runAsync(() async {
      await DaoTask().insert(
        Task.forInsert(
          jobId: job.id,
          name: 'Fixed scope',
          description: '',
          status: TaskStatus.inProgress,
          billingType: BillingType.fixedPrice,
        ),
      );
    });
    await showEditor(tester, job);
    await pumpUntil(tester, find.text('Billing type: Mixed'));
    expect(
      find.text('Job default: ${job.billingType.display}'),
      findsOneWidget,
    );
  });

  for (final resetDefaults in [false, true]) {
    testWidgets(
      'billing saves automatic recipient; reset old defaults: $resetDefaults',
      (tester) async {
        final job = await seed(tester);
        await tester.runAsync(() async {
          job.billingContactId = null;
          await DaoJob().update(job);
          job.legacyBillingContactId = job.contactId;
          await DaoJob().update(job);
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) =>
                Stack(children: [child!, const BlockingOverlay()]),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => JobEditScreen(
                        job: job,
                        section: JobEditSection.billing,
                      ),
                    ),
                  ),
                  child: const Text('Open billing'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open billing'));
        await pumpUntil(tester, find.text('Bill To customer'));
        await pumpUntil(tester, find.byType(TextFormField));
        if (resetDefaults) {
          await tester.tap(find.text('Use current defaults'));
          await tester.pump();
        }
        await tester.tap(find.text('Save'));
        await pumpUntil(tester, find.text('Open billing'));
        await tester.runAsync(() async {
          final saved = (await DaoJob().getById(job.id))!;
          expect(saved.billingContactId, isNull);
          expect(saved.hourlyRate, MoneyEx.dollars(95));
          expect(
            saved.legacyBillingContactId,
            resetDefaults ? isNull : job.contactId,
          );
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  var stable = 0;
  for (var attempt = 0; attempt < 300; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    if (finder.evaluate().isNotEmpty &&
        !June.getState(BlockingOverlayState.new).blocked) {
      if (++stable >= 25) {
        return;
      }
    } else {
      stable = 0;
    }
  }
  expect(finder, findsWidgets);
}
