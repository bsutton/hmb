@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
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
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

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
