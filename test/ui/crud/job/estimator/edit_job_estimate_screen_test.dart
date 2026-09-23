@Tags(['flutter'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/crud/job/estimator/edit_job_estimate_screen.dart';
import 'package:hmb/ui/quoting/list_quote_screen.dart';
import 'package:hmb/ui/widgets/media/photo_gallery.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money2/money2.dart';
import 'package:toastification/toastification.dart';

import '../../../../database/management/db_utility_test_helper.dart';
import '../../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(tearDownTestDb);

  testWidgets('raising a completed estimate opens the job quote list', (
    tester,
  ) async {
    late Job job;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.dollars(100),
        bookingFee: MoneyEx.dollars(50),
        summary: 'Ready estimate',
      );
      await DaoTask().insert(
        Task.forInsert(
          jobId: job.id,
          name: 'Completed scope',
          description: '',
          status: TaskStatus.awaitingApproval,
          estimateComplete: true,
        ),
      );
    });
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(home: JobEstimateBuilderScreen(job: job)),
      ),
    );
    await _pumpUntilFound(tester, find.text('Raise Quote'));
    await tester.tap(find.text('Raise Quote'));
    await _pumpUntilFound(tester, find.text('Bill booking Fee'));
    final booking = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Bill booking Fee'),
    );
    if (booking.value != true) {
      await tester.tap(find.text('Bill booking Fee'));
      await tester.pump();
    }
    await tester.tap(find.text('OK'));
    await _pumpUntilFound(tester, find.byType(QuoteListScreen));
    final screen = tester.widget<QuoteListScreen>(find.byType(QuoteListScreen));
    expect(screen.job?.id, job.id);
    await tester.runAsync(() async {
      final quote = (await DaoQuote().getByJobId(job.id)).single;
      expect(quote.jobId, job.id);
      expect(quote.totalAmount, MoneyEx.dollars(50));
    });
    await _pumpUntilFound(tester, find.text('Send...'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await _pumpUntilFound(tester, find.text('Raise Quote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quotes'));
    await _pumpUntilFound(tester, find.byType(QuoteListScreen));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await _pumpUntilFound(tester, find.text('Raise Quote'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('item margin replaces job margin in estimate and raised quote', (
    tester,
  ) async {
    late Job job;
    final jobMargin = Percentage.tryParse('20')!;
    final itemMargin = Percentage.tryParse('25')!;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.dollars(100),
        status: JobStatus.inProgress,
      );
      job = job.copyWith(estimateMargin: jobMargin);
      await DaoJob().update(job);
      final task = Task.forInsert(
        jobId: job.id,
        name: 'Margin task',
        description: '',
        status: TaskStatus.inProgress,
        estimateComplete: true,
      );
      await DaoTask().insert(task);
      for (final margin in [Percentage.zero, itemMargin]) {
        await DaoTaskItem().insert(
          TaskItem.forInsert(
            taskId: task.id,
            description: 'Material $margin',
            purpose: '',
            itemType: TaskItemType.materialsBuy,
            estimatedPrice: MaterialPrice.items(
              quantity: Fixed.one,
              unitCost: MoneyEx.dollars(100),
            ),
            chargeMode: ChargeMode.calculated,
            margin: margin,
            measurementType: MeasurementType.length,
            dimension1: Fixed.zero,
            dimension2: Fixed.zero,
            dimension3: Fixed.zero,
            units: Units.m,
            url: '',
            labourEntryMode: LabourEntryMode.hours,
          ),
        );
      }
    });
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(home: JobEstimateBuilderScreen(job: job)),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.text('Task total: ${MoneyEx.dollars(245)}'),
    );
    expect(find.text('Total: ${MoneyEx.dollars(245)}'), findsOneWidget);
    expect(find.textContaining('(from job)'), findsOneWidget);
    expect(find.textContaining('(item override)'), findsOneWidget);
    expect(tester.getSize(find.byType(PhotoGallery)).height, 0);
    await tester.tap(find.text('Raise Quote'));
    await _pumpUntilFound(tester, find.text('Select All'));
    await tester.tap(find.text('OK'));
    await _pumpUntilFound(tester, find.byType(QuoteListScreen));
    await tester.runAsync(() async {
      final quote = (await DaoQuote().getByJobId(job.id)).single;
      expect(quote.totalAmount, MoneyEx.dollars(245));
      expect(quote.quoteMargin, Percentage.zero);
      final lines = await DaoQuoteLine().getByQuoteId(quote.id);
      expect(
        lines.map((line) => line.lineTotal),
        unorderedEquals([MoneyEx.dollars(120), MoneyEx.dollars(125)]),
      );
    });
    await _pumpUntilFound(tester, find.text('Send...'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('raising a quote requires every estimate to be complete', (
    tester,
  ) async {
    late Job job;
    await tester.runAsync(() async {
      job = await createJobWithCustomer(
        billingType: BillingType.fixedPrice,
        hourlyRate: MoneyEx.zero,
        summary: 'Incomplete estimate',
      );
      await DaoTask().insert(
        Task.forInsert(
          jobId: job.id,
          name: 'Still estimating',
          description: '',
          status: TaskStatus.awaitingApproval,
        ),
      );
    });

    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(home: JobEstimateBuilderScreen(job: job)),
      ),
    );
    await _pumpUntilFound(tester, find.text('Raise Quote'));

    expect(find.text('Estimate Complete: No'), findsOneWidget);
    expect(find.textContaining('Labour:'), findsNothing);
    await tester.tap(find.text('Show costs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Labour:'), findsOneWidget);
    expect(find.textContaining('Materials:'), findsOneWidget);
    await tester.tap(find.text('Hide costs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Labour:'), findsNothing);
    await tester.tap(find.text('Raise Quote'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining(
        'Mark every task estimate as complete',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('Tasks for Quote'), findsNothing);
    toastification.dismissAll();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quotes'));
    await _pumpUntilFound(tester, find.byType(QuoteListScreen));
    expect(
      tester.widget<QuoteListScreen>(find.byType(QuoteListScreen)).job?.id,
      job.id,
    );
    await tester.runAsync(() async {
      expect(await DaoQuote().getByJobId(job.id), isEmpty);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    // Drain the diagnostic timers retained by asynchronous helpers.
    await tester.pump(const Duration(seconds: 10));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Timed out waiting for $finder');
}
