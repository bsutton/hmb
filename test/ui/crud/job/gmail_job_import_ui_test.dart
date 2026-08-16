@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/integrations/gmail/gmail_import_service.dart';
import 'package:hmb/ui/crud/job/gmail_job_import_screen.dart';
import 'package:hmb/ui/crud/job/job_creation_email_source.dart';
import 'package:hmb/ui/crud/job/job_creator.dart';
import 'package:hmb/ui/crud/job/list_job_screen.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/ui/widgets/icons/hmb_add_button.dart';
import 'package:june/june.dart';

import '../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  testWidgets('new job menu offers Gmail import', (tester) async {
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

    final overlay = June.getState(BlockingOverlayState.new);
    expect(overlay.blocked, isTrue);
    expect(overlay.topAction.canCancel, isTrue);
    await overlay.topAction.cancel();
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

  @override
  Future<GmailSearchResult> search({
    String query = 'newer_than:30d',
    String? textFilter,
    String? pageToken,
    int maxResults = 30,
  }) {
    if (query.contains('needle')) {
      return _filtered.future;
    }
    return Future.value(_recentResult());
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

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
  await tester.pump();
}
