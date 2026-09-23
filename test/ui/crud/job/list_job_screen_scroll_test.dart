@Tags(['flutter'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_full_screen/list_entity_screen.dart';
import 'package:hmb/ui/crud/job/list_job_card.dart';
import 'package:hmb/ui/crud/job/list_job_screen.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await setupTestDb();
  });

  tearDown(() async {
    await tearDownTestDb();
  });

  for (final showOld in [false, true]) {
    testWidgets('completed unbilled work uses old filter: $showOld', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({
        'job_list_filter_show_current': 'true',
        'job_list_filter_show_old': '$showOld',
      });
      late Job completed;
      await tester.runAsync(() async {
        await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          summary: 'Recent job 3',
        );
        completed = await createJobWithCustomer(
          billingType: BillingType.fixedPrice,
          hourlyRate: MoneyEx.zero,
          summary: 'Completed but not billed',
          status: JobStatus.completed,
        );
      });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: JobListScreen())),
      );
      final listFinder = find.byType(EntityListScreen<Job>);
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        if (listFinder.evaluate().isNotEmpty &&
            tester
                .state<EntityListScreenState<Job>>(listFinder)
                .entityList
                .isNotEmpty) {
          break;
        }
      }
      final entries = tester
          .state<EntityListScreenState<Job>>(find.byType(EntityListScreen<Job>))
          .entityList;
      expect(entries, isNotEmpty);
      expect(entries.any((job) => job.id == completed.id), showOld);
      await _disposeHarness(tester);
    });
  }

  testWidgets('narrow job cards grow to fit their contents', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await createJobWithCustomer(
        billingType: BillingType.timeAndMaterial,
        hourlyRate: MoneyEx.zero,
        summary: 'Recent job 3',
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(child: SizedBox(width: 390, child: JobListScreen())),
        ),
      ),
    );
    await _pumpUntilJobsLoad(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await _disposeHarness(tester);
  });

  testWidgets('scrolling back retains loaded job cards', (tester) async {
    await tester.runAsync(() async {
      for (var index = 0; index < 8; index++) {
        await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          summary: 'Recent job $index',
        );
      }
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: JobListScreen())),
    );
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final card = find.byType(ListJobCard).first;
    final originalState = tester.state(card);
    final originalKey = tester.widget<ListJobCard>(card).key!;
    final originalHeight = tester.getSize(card).height;
    expect(originalHeight, greaterThan(200));
    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!
          ..jumpTo(2500);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(originalState.mounted, isTrue);
    controller.jumpTo(0);
    await tester.pump();
    expect(tester.state(find.byKey(originalKey)), same(originalState));
    expect(tester.getSize(find.byKey(originalKey)).height, originalHeight);
    expect(tester.takeException(), isNull);
    await _disposeHarness(tester);
  });

  testWidgets('returning to recent jobs resets the scroll position', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var index = 0; index < 4; index++) {
        await createJobWithCustomer(
          billingType: BillingType.timeAndMaterial,
          hourlyRate: MoneyEx.zero,
          summary: 'Recent job $index',
        );
      }
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: JobListScreen())),
    );
    await _pumpUntilJobsLoad(tester);

    final listFinder = find.byType(ListView);
    await tester.drag(listFinder, const Offset(0, -600));
    await tester.pump(const Duration(seconds: 1));
    final list = tester.widget<ListView>(listFinder);
    expect(list.controller!.offset, greaterThan(0));

    tester
        .state<EntityListScreenState<Job>>(find.byType(EntityListScreen<Job>))
        .didPopNext();
    await _pumpUntilScrolledToTop(tester, list.controller!);

    expect(list.controller!.offset, 0);
    await _disposeHarness(tester);
  });
}

Future<void> _pumpUntilJobsLoad(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump();
    if (find.text('Recent job 3').evaluate().isNotEmpty) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Job list did not load.');
}

Future<void> _pumpUntilScrolledToTop(
  WidgetTester tester,
  ScrollController controller,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump();
    if (controller.offset == 0) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail('Job list did not reset its scroll position.');
}

Future<void> _disposeHarness(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}
