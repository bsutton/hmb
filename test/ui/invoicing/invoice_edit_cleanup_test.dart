@Tags(['flutter'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/debtor_ledger_service.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/invoicing/edit_invoice_line_dialog.dart';
import 'package:hmb/ui/invoicing/edit_invoice_screen.dart';
import 'package:hmb/ui/invoicing/invoice_accounting_state.dart';
import 'package:hmb/ui/invoicing/invoice_details.dart';
import 'package:hmb/ui/invoicing/invoice_discount_dialog.dart';
import 'package:hmb/ui/invoicing/invoice_editor_actions.dart';
import 'package:hmb/ui/invoicing/invoice_send_button.dart';
import 'package:hmb/ui/invoicing/quickbooks_export_screen.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/ui/widgets/hmb_chip.dart';
import 'package:hmb/ui/widgets/layout/surface.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:hmb/util/dart/local_date.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';

void main() {
  for (final source in [
    InvoicePaymentSource.xero,
    InvoicePaymentSource.unknown,
  ]) {
    testWidgets('upload precedes send with integrated tracking: $source', (
      tester,
    ) async {
      final details = _details();
      details.invoice.paymentSource = source;
      await _pump(
        tester,
        loadDetails: (_) async => details,
        loadAccounting: (_) async => const InvoiceAccountingState(
          destination: InvoiceAccountingDestination.synced,
        ),
      );
      final surface = find.ancestor(
        of: find.text('Billing & delivery'),
        matching: find.byType(Surface),
      );
      final upload = find.widgetWithText(HMBButtonSecondary, 'Upload');
      final send = find.widgetWithText(HMBButton, 'Preview / send');
      expect(find.descendant(of: surface, matching: upload), findsOneWidget);
      expect(find.descendant(of: surface, matching: send), findsOneWidget);
      expect(
        tester.getTopLeft(upload).dy,
        lessThan(tester.getTopLeft(send).dy),
      );
      expect(find.text('Accounting upload pending'), findsOneWidget);
      expect(find.text('Payment tracking needs review'), findsNothing);
      expect(find.text('Track payments in HMB'), findsNothing);
      expect(find.text('Manage payments'), findsNothing);
      expect(find.textContaining('The connection is checked'), findsNothing);
    });
  }

  testWidgets('integrated invoices do not offer local payment entry', (
    tester,
  ) async {
    final details = _details(sent: true);
    details.invoice.paymentSource = InvoicePaymentSource.xero;
    details.invoice.externalInvoiceId = 'fixture-id';
    await _pump(
      tester,
      loadDetails: (_) async => details,
      loadAccounting: (_) async => const InvoiceAccountingState(
        destination: InvoiceAccountingDestination.synced,
      ),
    );
    expect(find.text('Synced with accounting'), findsOneWidget);
    expect(find.text('Record or allocate payment'), findsNothing);
    expect(find.text('Track payments in HMB'), findsNothing);
  });

  for (final entry in {
    DebtorInvoiceStatus.draft: 'Draft',
    DebtorInvoiceStatus.sent: 'Outstanding',
    DebtorInvoiceStatus.partPaid: 'Part paid',
    DebtorInvoiceStatus.paid: 'Paid',
    DebtorInvoiceStatus.credited: 'Credited',
    DebtorInvoiceStatus.overpaid: 'Overpaid',
    DebtorInvoiceStatus.voided: 'Voided',
    DebtorInvoiceStatus.writtenOff: 'Written off',
  }.entries) {
    testWidgets('invoice status badge shows ${entry.value}', (tester) async {
      await _pump(
        tester,
        loadDetails: (_) async => _details(status: entry.key),
      );
      expect(tester.widget<HMBChip>(find.byType(HMBChip)).label, entry.value);
    });
  }

  testWidgets('tracking states replace redundant accounting labels', (
    tester,
  ) async {
    final details = _details();
    for (final state in [
      (
        InvoicePaymentSource.xero,
        InvoiceExternalSyncStatus.none,
        'Accounting upload pending',
      ),
      (
        InvoicePaymentSource.unknown,
        InvoiceExternalSyncStatus.none,
        'Payment tracking needs review',
      ),
      (
        InvoicePaymentSource.xero,
        InvoiceExternalSyncStatus.deleted,
        'Deleted in accounting',
      ),
      (
        InvoicePaymentSource.xero,
        InvoiceExternalSyncStatus.voided,
        'Voided in accounting',
      ),
    ]) {
      details.invoice.paymentSource = state.$1;
      details.invoice.externalSyncStatus = state.$2;
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, loadDetails: (_) async => details);
      expect(find.text(state.$3), findsOneWidget);
      expect(find.textContaining('Linked to accounting'), findsNothing);
      expect(find.textContaining('Payment tracking:'), findsNothing);
    }
  });

  testWidgets('history shows receipt date and hides payment plumbing', (
    tester,
  ) async {
    await _pump(
      tester,
      loadDetails: (_) async => _details(
        sent: true,
        history: [
          InvoiceLedgerHistoryEntry(
            type: InvoiceLedgerHistoryEntryType.payment,
            date: DateTime(2026, 10, 14),
            paymentDate: DateTime(2026, 10, 12),
            amount: MoneyEx.dollars(50),
            title: 'Payment received',
            detail: 'Xero · 00000000-0000-0000-0000-000000000000',
          ),
          InvoiceLedgerHistoryEntry(
            type: InvoiceLedgerHistoryEntryType.credit,
            date: DateTime(2026, 10, 13),
            amount: MoneyEx.dollars(10),
            title: 'Credit applied',
            detail: 'Goodwill credit',
          ),
        ],
      ),
    );
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('12 Oct 2026'), findsOneWidget);
    expect(find.text('14 Oct 2026'), findsNothing);
    expect(find.textContaining('00000000'), findsNothing);
    expect(find.textContaining('Xero'), findsNothing);
    expect(find.text('Payment received'), findsNothing);
    expect(find.text('Goodwill credit'), findsOneWidget);
    await tester.ensureVisible(find.text('Payment history'));
    await tester.tap(find.text('Payment history'));
    await tester.pumpAndSettle();
    expect(find.text('Received'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section surfaces share one page inset and group line rows', (
    tester,
  ) async {
    await _pump(tester, loadDetails: (_) async => _details(includeLines: true));
    final summarySurface = find.ancestor(
      of: find.text('Invoice status'),
      matching: find.byType(Surface),
    );
    final billingSurface = find.ancestor(
      of: find.text('Billing & delivery'),
      matching: find.byType(Surface),
    );
    expect(summarySurface, findsOneWidget);
    expect(billingSurface, findsOneWidget);
    expect(tester.getTopLeft(summarySurface).dx, 16);
    expect(tester.getTopLeft(billingSurface).dx, 16);
    final lineSurface = find.ancestor(
      of: find.text('Replace damaged bathroom fittings and seal edges'),
      matching: find.byType(Surface),
    );
    expect(lineSurface, findsOneWidget);
    expect(tester.getTopLeft(lineSurface).dx, 16);
    expect(
      find.descendant(of: lineSurface, matching: find.text('Repairs')),
      findsOneWidget,
    );
  });

  for (final accountingEnabled in [false, true]) {
    test(
      'legacy local invoice email with accounting enabled=$accountingEnabled',
      () async {
        var prepared = false;
        var accountingLookups = 0;
        final result = await checkInvoiceEmailAvailability(
          invoice: _details().invoice,
          prepareBillingContact: () async {
            prepared = true;
          },
          isAccountingEnabled: () async {
            accountingLookups++;
            return accountingEnabled;
          },
        );
        expect(prepared, isTrue);
        expect(result.blocked, isFalse);
        expect(accountingLookups, 0);
      },
    );
  }

  test(
    'unknown accounting settings block sending with retry guidance',
    () async {
      final result = await checkInvoiceEmailAvailability(
        invoice: _details().invoice..paymentSource = InvoicePaymentSource.xero,
        prepareBillingContact: () async {},
        isAccountingEnabled: () async => throw StateError('disconnected'),
      );
      expect(result.blocked, isTrue);
      expect(result.reason, contains('Retry before sending'));
    },
  );

  test('email still validates contacts and voided invoice state', () async {
    final invoice = _details().invoice;
    var result = await checkInvoiceEmailAvailability(
      invoice: invoice,
      prepareBillingContact: () async =>
          throw InvoiceException('Email required'),
    );
    expect(result.blocked, isTrue);
    expect(result.reason, 'Email required');
    invoice.externalSyncStatus = InvoiceExternalSyncStatus.voided;
    result = await checkInvoiceEmailAvailability(
      invoice: invoice,
      prepareBillingContact: () async =>
          fail('Must not prepare a void invoice'),
    );
    expect(result.blocked, isTrue);
  });

  test(
    'external tracking preserves upload-first rule only when enabled',
    () async {
      final invoice = _details().invoice
        ..paymentSource = InvoicePaymentSource.xero;
      for (final enabled in [false, true]) {
        final result = await checkInvoiceEmailAvailability(
          invoice: invoice,
          prepareBillingContact: () async {},
          isAccountingEnabled: () async => enabled,
        );
        expect(result.blocked, enabled);
      }
      invoice.externalInvoiceId = 'sample-upload';
      final uploaded = await checkInvoiceEmailAvailability(
        invoice: invoice,
        prepareBillingContact: () async {},
        isAccountingEnabled: () async => throw StateError('must not check'),
      );
      expect(uploaded.blocked, isFalse);
    },
  );

  test('configured disconnected snapshot does not promise sending', () {
    final state = InvoiceAccountingState.resolve(
      syncEnabled: false,
      snapshotConnected: false,
      snapshotConfigured: true,
    );
    expect(state.destination, InvoiceAccountingDestination.disconnected);
    expect(state.canUpload, isFalse);
    expect(state.explanation, isNot(contains('sending remains available')));
    final configured = InvoiceAccountingState.resolve(
      syncEnabled: true,
      snapshotConnected: false,
    );
    expect(configured.explanation, contains('Upload is required before email'));
  });

  testWidgets(
    'no provider shows local tracking without an accounting setup warning',
    (tester) async {
      await _pump(tester, loadDetails: (_) async => _details(sent: true));
      expect(find.text('Billing & delivery'), findsOneWidget);
      expect(find.text('Accounting upload'), findsNothing);
      expect(find.text('Payments tracked in HMB'), findsOneWidget);
      expect(
        find.text('Record payments here as they’re received.'),
        findsOneWidget,
      );
      expect(find.text('Record or allocate payment'), findsOneWidget);
      expect(
        tester
            .widget<HMBButton>(find.widgetWithText(HMBButton, 'View / resend'))
            .onPressed,
        isNotNull,
      );
      expect(find.text('Upload'), findsNothing);
      expect(
        find.textContaining('You can send this invoice without accounting.'),
        findsNothing,
      );
      expect(find.textContaining('to send this invoice'), findsNothing);
    },
  );

  test(
    'accounting routing handles absent, single and conflicting providers',
    () {
      expect(
        InvoiceAccountingState.resolve(
          syncEnabled: false,
          snapshotConnected: false,
        ).canUpload,
        isFalse,
      );
      expect(
        InvoiceAccountingState.resolve(
          syncEnabled: true,
          snapshotConnected: false,
        ).destination,
        InvoiceAccountingDestination.synced,
      );
      expect(
        InvoiceAccountingState.resolve(
          syncEnabled: false,
          snapshotConnected: true,
        ).destination,
        InvoiceAccountingDestination.snapshot,
      );
      expect(
        InvoiceAccountingState.resolve(
          syncEnabled: true,
          snapshotConnected: true,
        ).canUpload,
        isFalse,
      );
      expect(
        InvoiceAccountingState.resolve(
          syncEnabled: true,
          snapshotConnected: false,
          hasSnapshotAttempt: true,
        ).canUpload,
        isFalse,
      );
    },
  );

  test('snapshot status distinguishes uncertain and completed exports', () {
    final pending = InvoiceAccountingState.resolve(
      syncEnabled: false,
      snapshotConnected: true,
      hasSnapshotAttempt: true,
    );
    expect(pending.explanation, contains('before retrying'));
    final complete = InvoiceAccountingState.resolve(
      syncEnabled: false,
      snapshotConnected: true,
      hasSnapshotAttempt: true,
      snapshotComplete: true,
    );
    expect(complete.explanation, contains('reconciled separately'));
    final disconnected = InvoiceAccountingState.resolve(
      syncEnabled: false,
      snapshotConnected: false,
      hasSnapshotAttempt: true,
    );
    expect(disconnected.canUpload, isFalse);
    expect(disconnected.explanation, contains('original'));
  });

  test(
    'lifecycle action matrix preserves corrections and legacy allocations',
    () {
      List<bool> actions(InvoiceDetails details) {
        final policy = InvoiceEditorActions(details);
        return [
          policy.canEdit,
          policy.canAllocate,
          policy.canAdjust,
          policy.canWriteOff,
          policy.canVoid,
        ];
      }

      expect(actions(_details()), [true, false, false, false, false]);
      expect(actions(_details(sent: true)), [false, true, true, true, true]);
      expect(
        actions(
          _details(
            paid: MoneyEx.dollars(20),
            balance: MoneyEx.dollars(80),
            status: DebtorInvoiceStatus.partPaid,
          ),
        ),
        [false, true, true, true, false],
      );
      expect(
        actions(
          _details(
            sent: true,
            credited: MoneyEx.dollars(20),
            balance: MoneyEx.dollars(80),
            status: DebtorInvoiceStatus.credited,
          ),
        ),
        [false, true, true, true, false],
      );
      for (final status in [
        DebtorInvoiceStatus.paid,
        DebtorInvoiceStatus.overpaid,
        DebtorInvoiceStatus.writtenOff,
      ]) {
        expect(
          actions(
            _details(
              sent: true,
              paid: MoneyEx.dollars(100),
              balance: status == DebtorInvoiceStatus.overpaid
                  ? MoneyEx.dollars(-10)
                  : MoneyEx.zero,
              status: status,
            ),
          ),
          [false, false, true, false, false],
        );
      }
      final external = _details(sent: true);
      external.invoice.externalInvoiceId = 'fixture-id';
      external.invoice.paymentSource = InvoicePaymentSource.xero;
      expect(actions(external), [false, false, false, false, true]);
      external.invoice.externalSyncStatus = InvoiceExternalSyncStatus.voided;
      expect(actions(external), [false, false, false, false, false]);
      final unknown = _details();
      unknown.invoice.paymentSource = InvoicePaymentSource.unknown;
      expect(InvoiceEditorActions(unknown).hasPaymentActions, isFalse);
      unknown.invoice.externalSyncStatus = InvoiceExternalSyncStatus.deleted;
      expect(InvoiceEditorActions(unknown).hasPaymentActions, isFalse);
    },
  );

  testWidgets('draft has editing and delivery without financial clutter', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Preview / send'), findsOneWidget);
    expect(find.text('Add Discount'), findsOneWidget);
    expect(find.text('Manage payments'), findsNothing);
    expect(find.textContaining('Credited:'), findsNothing);
    expect(find.textContaining('Adjusted:'), findsNothing);
    expect(find.textContaining('Not synced'), findsNothing);
    expect(find.text('More invoice actions'), findsNothing);
    expect(find.text('Record or allocate payment'), findsNothing);
  });

  testWidgets('sent invoice consolidates payments and hides exceptions', (
    tester,
  ) async {
    await _pump(tester, loadDetails: (_) async => _details(sent: true));
    expect(find.text('View / resend'), findsOneWidget);
    expect(find.text('Add Discount'), findsNothing);
    expect(find.text('Record or allocate payment'), findsOneWidget);
    expect(find.text('Record Payment'), findsNothing);
    expect(find.text('Allocate Payment'), findsNothing);
    expect(find.text('Add Adjustment'), findsNothing);
    await tester.ensureVisible(find.text('More invoice actions'));
    await tester.tap(find.text('More invoice actions'));
    await tester.pumpAndSettle();
    expect(find.text('Add Adjustment'), findsOneWidget);
    expect(find.text('Write Off'), findsOneWidget);
    expect(find.text('Void Invoice'), findsOneWidget);
  });

  testWidgets('settled invoice keeps correction without payment or write-off', (
    tester,
  ) async {
    await _pump(
      tester,
      loadDetails: (_) async => _details(
        sent: true,
        paid: MoneyEx.dollars(100),
        balance: MoneyEx.zero,
        status: DebtorInvoiceStatus.paid,
      ),
    );
    expect(find.text('Record or allocate payment'), findsNothing);
    await tester.ensureVisible(find.text('More invoice actions'));
    await tester.tap(find.text('More invoice actions'));
    await tester.pumpAndSettle();
    expect(find.text('Add Adjustment'), findsOneWidget);
    expect(find.text('Write Off'), findsNothing);
    expect(find.text('Void Invoice'), findsNothing);
    expect(find.text('Add Discount'), findsNothing);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('invoice sections wrap at $width with 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        scale: 2,
        loadDetails: (_) async => _details(includeLines: true),
      );
      expect(find.text('QuickBooks export'), findsNothing);
      expect(find.text('Upload to Xero'), findsNothing);
      expect(find.text('Upload'), findsNothing);
      await tester.ensureVisible(find.text('Invoice items'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Connect accounting'), findsNothing);
    });
  }

  testWidgets('uploaded and voided invoices retain editing restrictions', (
    tester,
  ) async {
    final details = _details();
    details.invoice.externalInvoiceId = 'fixture-external-id';
    details.invoice.externalSyncStatus = InvoiceExternalSyncStatus.linked;
    details.invoice.paymentSource = InvoicePaymentSource.xero;
    await _pump(tester, loadDetails: (_) async => details);
    expect(find.text('Upload'), findsNothing);
    expect(find.text('Add Discount'), findsNothing);
    expect(find.text('Synced with accounting'), findsOneWidget);
    expect(find.textContaining('Linked to accounting'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    details.invoice.externalSyncStatus = InvoiceExternalSyncStatus.voided;
    await _pump(tester, loadDetails: (_) async => details);
    expect(find.text('Delivery'), findsNothing);
    expect(find.text('Manage payments'), findsNothing);
    expect(find.textContaining('Voided in accounting'), findsOneWidget);
    expect(find.text('No email address recorded.'), findsOneWidget);
    expect(find.textContaining('before sending'), findsNothing);
  });

  testWidgets('manual tracking cannot acquire a sync upload action', (
    tester,
  ) async {
    await _pump(
      tester,
      loadAccounting: (_) async => const InvoiceAccountingState(
        destination: InvoiceAccountingDestination.synced,
      ),
    );
    expect(
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Upload'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text('This older invoice uses local payment tracking.'),
      findsOneWidget,
    );
  });

  testWidgets('line cancel and back discard unsaved edits', (tester) async {
    final line = InvoiceLine.forInsert(
      invoiceId: 1,
      description: 'Repair',
      quantity: Fixed.fromInt(1),
      unitPrice: MoneyEx.dollars(20),
      lineTotal: MoneyEx.dollars(20),
      invoiceLineGroupId: 1,
    );
    InvoiceLine? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<InvoiceLine>(
                  context: context,
                  builder: (_) => EditInvoiceLineDialog(line: line),
                );
              },
              child: const Text('Open line'),
            ),
          ),
        ),
      ),
    );
    for (final useBack in [false, true]) {
      await tester.tap(find.text('Open line'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Unsaved description',
      );
      if (useBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(line.description, 'Repair');
      expect(line.lineTotal, MoneyEx.dollars(20));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('load failure offers retry and recovers', (tester) async {
    var attempts = 0;
    await _pump(
      tester,
      loadDetails: (_) async {
        if (++attempts == 1) {
          throw StateError('fixture load failure');
        }
        return _details();
      },
    );
    expect(find.textContaining('Could not load this invoice'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Billing & delivery'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated accounting taps share one connection check', (
    tester,
  ) async {
    var calls = 0;
    final check = Completer<InvoiceAccountingState>();
    await _pump(
      tester,
      loadAccounting: (_) {
        calls++;
        return calls == 1
            ? Future.value(
                const InvoiceAccountingState(
                  destination: InvoiceAccountingDestination.snapshot,
                ),
              )
            : check.future;
      },
    );
    final button = tester.widget<HMBButtonSecondary>(
      find.widgetWithText(HMBButtonSecondary, 'Upload'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls, 2);
    check.complete(
      const InvoiceAccountingState(
        destination: InvoiceAccountingDestination.conflict,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('More than one accounting'), findsOneWidget);
    expect(
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Upload'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('provider change during check preserves manual tracking', (
    tester,
  ) async {
    var checks = 0;
    await _pump(
      tester,
      loadAccounting: (_) async => InvoiceAccountingState(
        destination: ++checks == 1
            ? InvoiceAccountingDestination.snapshot
            : InvoiceAccountingDestination.synced,
      ),
    );
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Upload'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(
      find.text('This older invoice uses local payment tracking.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Upload'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed accounting check recovers on retry', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      loadAccounting: (_) async {
        calls++;
        if (calls == 2) {
          throw StateError('fixture connection failure');
        }
        return InvoiceAccountingState(
          destination: calls == 1
              ? InvoiceAccountingDestination.snapshot
              : InvoiceAccountingDestination.none,
        );
      },
    );
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Upload'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not complete the accounting action'),
      findsOneWidget,
    );
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Upload'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(
      find.textContaining('Could not complete the accounting action'),
      findsNothing,
    );
    expect(find.textContaining('Connect accounting'), findsNothing);
    expect(find.text('Payments tracked in HMB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during accounting check does not navigate or throw', (
    tester,
  ) async {
    var calls = 0;
    final check = Completer<InvoiceAccountingState>();
    await _pump(
      tester,
      loadAccounting: (_) => ++calls == 1
          ? Future.value(
              const InvoiceAccountingState(
                destination: InvoiceAccountingDestination.snapshot,
              ),
            )
          : check.future,
    );
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Upload'),
        )
        .onPressed!();
    await tester.pumpWidget(const MaterialApp(home: Text('Other screen')));
    check.complete(
      const InvoiceAccountingState(
        destination: InvoiceAccountingDestination.snapshot,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Other screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('offsetting history remains protected and correctable', () {
    for (final sent in [false, true]) {
      final details = _details(
        sent: sent,
        history: [
          InvoiceLedgerHistoryEntry(
            type: InvoiceLedgerHistoryEntryType.adjustment,
            date: DateTime(2026),
            amount: MoneyEx.dollars(10),
            title: 'Adjustment',
          ),
          InvoiceLedgerHistoryEntry(
            type: InvoiceLedgerHistoryEntryType.adjustment,
            date: DateTime(2026),
            amount: MoneyEx.dollars(-10),
            title: 'Correction',
          ),
        ],
      );
      final policy = InvoiceEditorActions(details);
      expect(policy.canEdit, isFalse);
      expect(policy.canVoid, isFalse);
      expect(policy.canAdjust, isTrue);
      expect(policy.canAllocate, isTrue);
    }
  });

  testWidgets('accounting load failure retains local invoice and retries', (
    tester,
  ) async {
    var loads = 0;
    await _pump(
      tester,
      loadAccounting: (_) async {
        if (++loads == 1) {
          throw StateError('fixture settings failure');
        }
        return const InvoiceAccountingState(
          destination: InvoiceAccountingDestination.snapshot,
        );
      },
    );
    expect(find.text('Billing & delivery'), findsOneWidget);
    expect(find.text('Preview / send'), findsOneWidget);
    expect(
      find.textContaining('Could not load accounting settings'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Upload'),
          )
          .onPressed,
      isNull,
    );
    tester
        .widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Retry accounting settings'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not load accounting settings'),
      findsNothing,
    );
    expect(
      tester
          .widget<HMBButtonSecondary>(
            find.widgetWithText(HMBButtonSecondary, 'Upload'),
          )
          .onPressed,
      isNotNull,
    );
    expect(loads, 2);
  });

  for (final boundary in ['contact', 'failed contact', 'login']) {
    for (final leave in ['dispose', 'cover']) {
      testWidgets('leaving via $leave during $boundary prevents upload', (
        tester,
      ) async {
        final pending = Completer<void>();
        var contacts = 0;
        var logins = 0;
        var uploads = 0;
        final details = _details();
        details.invoice.paymentSource = InvoicePaymentSource.xero;
        await _pump(
          tester,
          loadDetails: (_) async => details,
          loadAccounting: (_) async => const InvoiceAccountingState(
            destination: InvoiceAccountingDestination.synced,
          ),
          prepareAccountingContact: (_) async {
            contacts++;
            if (boundary != 'login') {
              await pending.future;
            }
          },
          accountingLogin: () async {
            logins++;
            if (boundary == 'login') {
              await pending.future;
            }
          },
          accountingUpload: (_) async {
            uploads++;
          },
        );
        final button = tester.widget<HMBButtonSecondary>(
          find.widgetWithText(HMBButtonSecondary, 'Upload'),
        );
        button.onPressed!();
        button.onPressed!();
        await tester.pump();
        expect(contacts, 1);
        expect(logins, boundary == 'login' ? 1 : 0);
        if (leave == 'dispose') {
          await tester.pumpWidget(
            const MaterialApp(home: Text('Other screen')),
          );
        } else {
          Navigator.of(
            tester.element(find.byType(InvoiceEditScreen)),
          ).push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Other screen')),
            ),
          );
          await tester.pump();
        }
        if (boundary == 'failed contact') {
          pending.completeError(InvoiceException('Fixture contact failure'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(uploads, 0);
        expect(logins, boundary == 'login' ? 1 : 0);
        expect(find.text('Other screen'), findsOneWidget);
        expect(find.text('Billing contact needs attention'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('completed export shows review information without setup copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuickBooksExportScreen(
          invoice: _details().invoice,
          loadExport: (_) async => {
            'external_id': 'fixture-id',
            'external_number': 'INV-1',
            'remote_total': '100.00',
          },
          loadSandbox: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Accounting invoice: INV-1'), findsOneWidget);
    expect(find.textContaining('reconciled separately'), findsOneWidget);
    expect(find.textContaining('Export creates'), findsNothing);
    expect(find.text('Check customer'), findsNothing);
    expect(find.text('Confirm and export'), findsNothing);
  });

  testWidgets('export settings failure offers usable retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: QuickBooksExportScreen(
          invoice: _details().invoice,
          loadExport: (_) async {
            if (++attempts == 1) {
              throw StateError('fixture export failure');
            }
            return null;
          },
          loadSandbox: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load export settings.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Check customer'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discount validation keeps input and cancel returns nothing', (
    tester,
  ) async {
    InvoiceDiscountRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<InvoiceDiscountRequest>(
                  context: context,
                  builder: (_) => const InvoiceDiscountDialog(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Loyalty');
    await tester.enterText(find.byType(TextFormField).last, '-5');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(find.text('Loyalty'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '12.50');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(result?.description, 'Discount');
    expect(result?.amount, MoneyEx.tryParse('12.50'));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  double scale = 1,
  Future<InvoiceDetails> Function(int)? loadDetails,
  Future<InvoiceAccountingState> Function(int)? loadAccounting,
  Future<void> Function(Invoice)? prepareAccountingContact,
  Future<void> Function()? accountingLogin,
  Future<void> Function(Invoice)? accountingUpload,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: InvoiceEditScreen(
        invoiceDetails: _details(),
        prepareAccountingContact: prepareAccountingContact,
        accountingLogin: accountingLogin,
        accountingUpload: accountingUpload,
        loadDetails: loadDetails ?? (_) async => _details(),
        loadAccounting:
            loadAccounting ??
            (_) async => const InvoiceAccountingState(
              destination: InvoiceAccountingDestination.none,
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InvoiceDetails _details({
  bool sent = false,
  bool includeLines = false,
  Money? paid,
  Money? credited,
  Money? adjusted,
  Money? balance,
  DebtorInvoiceStatus? status,
  List<InvoiceLedgerHistoryEntry> history = const [],
}) {
  final invoice = Invoice.forInsert(
    jobId: 1,
    dueDate: LocalDate.today().addDays(7),
    totalAmount: MoneyEx.dollars(100),
    billingContactId: null,
    sent: sent,
  );
  final total = invoice.totalAmount;
  return InvoiceDetails(
    invoice: invoice,
    job: Job.forInsert(
      customerId: 1,
      summary: 'Bathroom repair',
      description: '',
      siteId: null,
      contactId: null,
      status: JobStatus.prospecting,
      hourlyRate: MoneyEx.zero,
      bookingFee: MoneyEx.zero,
      billingContactId: null,
    ),
    customer: Customer.forInsert(
      name: 'Test Customer',
      description: null,
      disbarred: false,
      customerType: CustomerType.residential,
      hourlyRate: MoneyEx.zero,
      billingContactId: null,
    ),
    ledger: InvoiceLedgerSummary(
      total: total,
      paid: paid ?? MoneyEx.zero,
      credited: credited ?? MoneyEx.zero,
      adjusted: adjusted ?? MoneyEx.zero,
      balance: balance ?? total,
      status:
          status ??
          (sent ? DebtorInvoiceStatus.sent : DebtorInvoiceStatus.draft),
    ),
    ledgerHistory: history,
    lineGroups: includeLines
        ? [
            InvoiceLineGroupDetails(
              group: InvoiceLineGroup.forInsert(invoiceId: 1, name: 'Repairs'),
              lines: [
                InvoiceLine.forInsert(
                  invoiceId: 1,
                  description:
                      'Replace damaged bathroom fittings and seal edges',
                  quantity: Fixed.parse('2'),
                  unitPrice: MoneyEx.dollars(50),
                  lineTotal: total,
                  invoiceLineGroupId: 1,
                ),
              ],
            ),
          ]
        : const [],
  );
}
