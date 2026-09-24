@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/dao_job_party.dart';
import 'package:hmb/dao/job_billing_contact.dart';
import 'package:hmb/entity/contact_role.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/integrations/gmail/gmail_import_service.dart';
import 'package:hmb/ui/crud/contact/contact_roles_screen.dart';
import 'package:hmb/ui/crud/job/gmail_job_import_screen.dart';
import 'package:hmb/ui/crud/job/job_creation_email_source.dart';
import 'package:hmb/ui/crud/job/job_creator.dart';
import 'package:hmb/ui/crud/job/list_job_screen.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../../util/settings_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  for (final separateSite in [false, true]) {
    testWidgets(
      'new customer import retains contact and addresses ($separateSite)',
      (tester) async {
        await prepareSettingsTest();
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final source = JobCreationEmailSource(
          accountEmail: 'owner@example.com',
          messageId: 'primary-contact-import',
          threadId: null,
          senderName: 'Casey Customer',
          senderEmail: 'casey@example.com',
          subject: 'Repair the tap',
          body: 'Please repair the tap.',
          receivedAt: DateTime.utc(2026, 8, 14),
          hasAttachments: false,
        );
        final otherJob = await tester.runAsync(
          () => createJobWithCustomer(
            billingType: BillingType.timeAndMaterial,
            hourlyRate: MoneyEx.zero,
            summary: 'Billing account fixture',
          ),
        );
        final billingCustomer = await tester.runAsync(
          () => DaoCustomer().getById(otherJob!.customerId),
        );
        final billingContact = await tester.runAsync(
          () => DaoContact().getById(otherJob!.contactId),
        );
        await tester.pumpWidget(
          ToastificationWrapper(
            child: MaterialApp(
              home: Scaffold(body: JobCreator(emailSource: source)),
            ),
          ),
        );
        await _pumpAsyncWork(tester);
        for (var step = 0; step < 6; step++) {
          if (step == 3) {
            await tester.enterText(
              find.widgetWithText(TextFormField, 'Address Line 1'),
              '10 Customer Street',
            );
            if (separateSite) {
              final toggle = find.byTooltip(
                'Use the customer address as the job site',
              );
              await tester.ensureVisible(toggle);
              await tester.pumpAndSettle();
              await tester.tap(toggle);
              await tester.pumpAndSettle();
              final siteField = find.widgetWithText(
                TextFormField,
                'Site address line 1',
              );
              await tester.ensureVisible(siteField);
              await tester.pumpAndSettle();
              await tester.enterText(siteField, '20 Work Street');
            }
          }
          if (step == 4 && !separateSite) {
            await tester.ensureVisible(find.text('Add party'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Add party'));
            await _pumpAsyncWork(tester);
            tester
                .widget<ContactRoleSelector>(find.byType(ContactRoleSelector))
                .onChanged(
                  const ContactRole(
                    id: ContactRole.site,
                    name: 'Site Contact',
                    builtin: true,
                  ),
                );
            await _pumpAsyncWork(tester);
            await tester.tap(find.text('Add Contact'));
            await _pumpAsyncWork(tester);
            await tester.enterText(
              find.widgetWithText(TextFormField, 'First Name'),
              'Sam',
            );
            await tester.enterText(
              find.widgetWithText(TextFormField, 'Surname'),
              'Access',
            );
            await tester.enterText(
              find.widgetWithText(TextFormField, 'Email'),
              'draft-access@example.test',
            );
            await tester.tap(find.text('Use contact'));
            await _pumpAsyncWork(tester);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Save'));
            await _pumpAsyncWork(tester);
            await tester.pumpAndSettle();
            expect(find.text('Sam Access'), findsOneWidget);
            expect(
              await tester.runAsync(
                () => DaoContact().getByEmail('draft-access@example.test'),
              ),
              isEmpty,
            );
          }
          if (step == 4 && separateSite) {
            await tester.ensureVisible(find.text('Add party'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Add party'));
            await _pumpAsyncWork(tester);
            tester
                .widget<ContactRoleSelector>(find.byType(ContactRoleSelector))
                .onChanged(
                  const ContactRole(
                    id: ContactRole.site,
                    name: 'Site Contact',
                    builtin: true,
                  ),
                );
            await tester.pumpAndSettle();
            tester
                .widget<HMBDroplist<Contact>>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is HMBDroplist<Contact> &&
                        widget.title == 'Contact',
                  ),
                )
                .onChanged(billingContact);
            await _pumpAsyncWork(tester);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Save'));
            await _pumpAsyncWork(tester);
            await tester.pumpAndSettle();
            expect(find.text('Site Contact'), findsOneWidget);
            expect(
              await tester.runAsync(
                () => DaoJobSourceEmail().getByMessage(
                  accountEmail: source.accountEmail,
                  messageId: source.messageId,
                ),
              ),
              isNull,
            );
          }
          if (step == 5) {
            final customerPicker = tester.widget<HMBDroplist<Customer>>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is HMBDroplist<Customer> &&
                    widget.title == 'Bill To customer',
              ),
            );
            final contactPicker = tester.widget<HMBDroplist<Contact>>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is HMBDroplist<Contact> &&
                    widget.title == 'Billing contact',
              ),
            );
            await tester.runAsync(() async {
              expect(
                (await customerPicker.selectedItem())?.name,
                source.senderName,
              );
              expect(
                (await contactPicker.selectedItem())?.emailAddress,
                source.senderEmail,
              );
            });
          }
          if (step == 5 && separateSite) {
            tester
                .widget<HMBDroplist<Customer>>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is HMBDroplist<Customer> &&
                        widget.title == 'Bill To customer',
                  ),
                )
                .onChanged(billingCustomer);
            await _pumpAsyncWork(tester);
            await tester.pumpAndSettle();
            final billingPicker = tester.widget<HMBDroplist<Contact>>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is HMBDroplist<Contact> &&
                    widget.title == 'Billing contact',
              ),
            );
            final choices = await tester.runAsync(
              () => billingPicker.items(null),
            );
            expect(
              choices!.map((contact) => contact.id),
              contains(billingContact!.id),
            );
            expect(
              choices.map((contact) => contact.emailAddress),
              isNot(contains(source.senderEmail)),
            );
            expect(
              (await tester.runAsync(billingPicker.selectedItem))?.id,
              billingContact.id,
            );
            billingPicker.onChanged(billingContact);
            await _pumpAsyncWork(tester);
            await tester.pumpAndSettle();
            final rate = find.byKey(const ValueKey('job-creator-hourly-rate'));
            await tester.ensureVisible(rate);
            await tester.pumpAndSettle();
            await tester.enterText(rate, '123.45');
          }
          await tester.tap(find.text('Next'));
          await _pumpAsyncWork(tester);
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, 'Job Summary'),
          200,
          scrollable: find
              .ancestor(
                of: find.text('Extract'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.widgetWithText(TextFormField, 'Job Summary'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .join(' | '),
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Job Summary'),
          source.subject,
        );
        await tester.tap(find.text('Done'));
        await _pumpAsyncWork(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip'));
        await _pumpAsyncWork(tester);
        await tester.pumpAndSettle();
        await _pumpAsyncWork(tester);

        await tester.runAsync(() async {
          final imported = await DaoJobSourceEmail().getByMessage(
            accountEmail: source.accountEmail,
            messageId: source.messageId,
          );
          expect(
            imported,
            isNotNull,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .join('\n'),
          );
          final job = (await DaoJob().getById(imported!.jobId))!;
          final contact = await DaoContact().getById(job.contactId);
          expect(contact, isNotNull);
          expect(contact!.emailAddress, source.senderEmail);
          expect(job.billingContactId, isNull);
          expect(
            (await DaoJobParty().getByJob(
              job.id,
            )).where((party) => party.role.id == ContactRole.billing),
            isEmpty,
          );
          expect(
            (await resolveJobBillingContact(job)).contact?.id,
            separateSite ? billingContact!.id : contact.id,
          );
          if (separateSite) {
            expect(job.billingCustomerId, billingCustomer!.id);
            expect(job.customerId, isNot(billingCustomer.id));
            expect(job.hourlyRate, MoneyEx.tryParse('123.45'));
            final parties = await DaoJobParty().getByJob(job.id);
            expect(
              parties.any(
                (party) =>
                    party.role.id == ContactRole.site &&
                    party.contact.id == billingContact!.id,
              ),
              isTrue,
            );
          }
          if (!separateSite) {
            final createdContacts = await DaoContact().getByEmail(
              'draft-access@example.test',
            );
            expect(createdContacts, hasLength(1));
            final parties = await DaoJobParty().getByJob(job.id);
            expect(
              parties.any(
                (party) =>
                    party.role.id == ContactRole.site &&
                    party.contact.id == createdContacts.single.id,
              ),
              isTrue,
            );
            expect(
              (await DaoContact().getByCustomer(
                job.customerId,
              )).any((contact) => contact.id == createdContacts.single.id),
              isTrue,
            );
          }
          final customerAddress = await DaoSite().getPrimaryForCustomer(
            job.customerId,
          );
          final siteAddress = await DaoSite().getById(job.siteId);
          expect(customerAddress!.addressLine1, '10 Customer Street');
          expect(
            siteAddress!.addressLine1,
            separateSite ? '20 Work Street' : '10 Customer Street',
          );
          expect(siteAddress.id == customerAddress.id, !separateSite);
        });
        // Let the wizard's completed transition timeout timers expire.
        await tester.pump(const Duration(seconds: 11));
      },
    );
  }

  test('Gmail attachment local names are readable and bounded', () {
    const original = 'Plinth board repair to front timber fence.pdf';
    expect(gmailAttachmentLocalFilename(original), original);
    expect(
      gmailAttachmentLocalFilename(original, duplicate: 2),
      'Plinth board repair to front timber fence (2).pdf',
    );

    final longName = '${List.filled(400, 'a').join()}.pdf';
    final localName = gmailAttachmentLocalFilename(longName);
    expect(localName.length, lessThanOrEqualTo(180));
    expect(localName, endsWith('.pdf'));
  });

  testWidgets('new job menu has aligned creation choices on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: JobListScreen())),
    );
    await _pumpAsyncWork(tester);

    final enabledAdd = find.byWidgetPredicate(
      (widget) => widget is HMBButtonAdd && widget.enabled,
    );
    await tester.tap(enabledAdd);
    await tester.pumpAndSettle();

    expect(find.text('Enter manually'), findsOneWidget);
    expect(find.text('Import from Gmail'), findsOneWidget);
    final manual = tester.getRect(
      find.widgetWithText(HMBButtonPrimary, 'Enter manually'),
    );
    final gmail = tester.getRect(
      find.widgetWithText(HMBButtonSecondary, 'Import from Gmail'),
    );
    expect(manual.left, gmail.left);
    expect(manual.right, gmail.right);
    expect(gmail.top - manual.bottom, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('email source remains available in the job wizard', (
    tester,
  ) async {
    final source = JobCreationEmailSource(
      accountEmail: 'owner@example.com',
      messageId: 'message-1',
      threadId: 'thread-1',
      senderName: 'Casey Customer',
      senderEmail: 'casey@example.com',
      subject: 'Leaking kitchen tap',
      body: 'The kitchen tap has been leaking since Monday.',
      receivedAt: DateTime.utc(2026, 8, 14),
      hasAttachments: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobCreator(emailSource: source)),
      ),
    );
    await _pumpAsyncWork(tester);

    await tester.tap(find.text('Source email'));
    await tester.pumpAndSettle();

    expect(find.text('Leaking kitchen tap'), findsOneWidget);
    expect(
      find.textContaining('The kitchen tap has been leaking since Monday.'),
      findsWidgets,
    );
    expect(find.text('Use subject'), findsOneWidget);
    expect(find.text('Replace description'), findsOneWidget);
    expect(find.text('Append description'), findsOneWidget);
  });

  testWidgets('Gmail import connects and searches when opened', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GmailJobImportScreen(service: _FakeGmailImportService()),
      ),
    );
    await _pumpAsyncWork(tester);

    expect(find.text('To, From or Subject'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('No matching email found.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Gmail connection and search can be cancelled', (tester) async {
    final service = _CancellableGmailImportService();
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GmailJobImportScreen(service: service),
            const BlockingOverlay(),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final overlay = June.getState(BlockingOverlayState.new);
    expect(overlay.blocked, isTrue);
    expect(overlay.topAction.canCancel, isTrue);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    final cancelButton = find.widgetWithText(HMBCancelButton, 'Cancel');
    expect(cancelButton, findsOneWidget);
    await tester.tap(cancelButton);
    await _pumpAsyncWork(tester);
    await tester.pumpAndSettle();

    expect(service.cancelled, isTrue);
    expect(find.text('Connect and search'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('clearing search restores results from the latest query', (
    tester,
  ) async {
    final service = _OverlappingGmailImportService();
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GmailJobImportScreen(service: service),
            const BlockingOverlay(),
          ],
        ),
      ),
    );
    await _pumpAsyncWork(tester);

    expect(find.text('Recent email'), findsOneWidget);

    final searchField = find.byType(TextFormField);
    await tester.enterText(searchField, 'needle');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.bySemanticsLabel('Searching Gmail'), findsOneWidget);
    await tester.enterText(searchField, '   ');
    await tester.pump(const Duration(milliseconds: 350));
    await _pumpAsyncWork(tester);

    service.completeFilteredSearch();
    await _pumpAsyncWork(tester);
    await tester.pumpAndSettle();

    expect(find.text('Recent email'), findsOneWidget);
    expect(find.text('No matching email found.'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('loads the next Gmail page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GmailJobImportScreen(service: _PaginatedGmailImportService()),
            const BlockingOverlay(),
          ],
        ),
      ),
    );
    await _pumpAsyncWork(tester);

    expect(find.text('First email'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await _pumpAsyncWork(tester);

    expect(find.text('First email'), findsOneWidget);
    expect(find.text('Second email'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _FakeGmailImportService extends GmailImportService {
  @override
  Future<GmailSearchResult> search({
    String query = 'newer_than:30d',
    String? textFilter,
    String? pageToken,
    int maxResults = 30,
  }) async => const GmailSearchResult(
    accountEmail: 'owner@example.com',
    messages: [],
    nextPageToken: null,
  );
}

class _CancellableGmailImportService extends GmailImportService {
  final _result = Completer<GmailSearchResult>();
  var cancelled = false;

  @override
  Future<GmailSearchResult> search({
    String query = 'newer_than:30d',
    String? textFilter,
    String? pageToken,
    int maxResults = 30,
  }) => _result.future;

  @override
  Future<void> cancelPendingOperation() async {
    cancelled = true;
    if (!_result.isCompleted) {
      _result.complete(
        const GmailSearchResult(
          accountEmail: '',
          messages: [],
          nextPageToken: null,
        ),
      );
    }
  }
}

class _OverlappingGmailImportService extends GmailImportService {
  final _filtered = Completer<GmailSearchResult>();
  var cancellationCount = 0;

  @override
  Future<GmailSearchResult> search({
    String query = 'newer_than:30d',
    String? textFilter,
    String? pageToken,
    int maxResults = 30,
  }) {
    if (textFilter == 'needle') {
      return _filtered.future;
    }
    return Future.value(_recentResult());
  }

  @override
  Future<void> cancelPendingOperation() async {
    cancellationCount++;
  }

  void completeFilteredSearch() {
    _filtered.complete(
      const GmailSearchResult(
        accountEmail: 'owner@example.com',
        messages: [],
        nextPageToken: null,
      ),
    );
  }

  GmailSearchResult _recentResult() => GmailSearchResult(
    accountEmail: 'owner@example.com',
    messages: [
      GmailMessageSummary(
        id: 'recent-message',
        threadId: 'recent-thread',
        sender: 'customer@example.com',
        subject: 'Recent email',
        snippet: 'Most recent unfiltered result',
        receivedAt: DateTime.utc(2026, 8, 16),
        hasAttachments: false,
      ),
    ],
    nextPageToken: null,
  );
}

class _PaginatedGmailImportService extends GmailImportService {
  @override
  Future<GmailSearchResult> search({
    String query = 'newer_than:30d',
    String? textFilter,
    String? pageToken,
    int maxResults = 30,
  }) async => GmailSearchResult(
    accountEmail: 'owner@example.com',
    messages: [
      GmailMessageSummary(
        id: pageToken == null ? 'first' : 'second',
        threadId: null,
        sender: 'customer@example.com',
        subject: pageToken == null ? 'First email' : 'Second email',
        snippet: 'Email body',
        receivedAt: DateTime.utc(2026, 8, 16),
        hasAttachments: false,
      ),
    ],
    nextPageToken: pageToken == null ? 'next-page' : null,
  );
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
  await tester.pump();
}
