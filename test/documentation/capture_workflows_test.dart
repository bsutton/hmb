@Tags(['flutter'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/ui/crud/base_nested/list_nested_screen.dart';
import 'package:hmb/ui/crud/system/system_billing_screen.dart';
import 'package:hmb/ui/crud/task/edit_task_screen.dart';
import 'package:hmb/ui/crud/task/list_task_screen.dart';
import 'package:hmb/ui/nav/home_scaffold.dart';
import 'package:hmb/ui/widgets/hmb_start_time_entry.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../database/management/db_utility_test_helper.dart';
import '../ui/ui_test_helpers.dart';
import '../util/settings_test_helper.dart';

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await resetSettingsForTest();
    await setupTestDb();
    // Only this disposable test database is changed. Never use production data.
    final system = await DaoSystem().getForUpdate();
    system
      ..businessName = 'Example Workshop'
      ..bsb = ''
      ..accountNo = ''
      ..paymentLinkUrl = ''
      ..paymentOptions = ''
      ..logoPath = ''
      ..defaultHourlyRate = MoneyEx.dollars(75)
      ..defaultBookingFee = MoneyEx.zero
      ..enableXeroIntegration = false
      ..enableIhserverIntegration = false;
    await DaoSystem().updateConfiguration(system);
    June.getState<ActiveTimeEntryState>(
      ActiveTimeEntryState.new,
    ).clearActiveTimeEntry();
  });
  tearDown(tearDownTestDb);

  testWidgets('capture billing actions and logo configuration', (tester) async {
    await prepareCapture(tester);
    final key = GlobalKey();
    await mount(tester, key, const SystemBillingScreen());
    final state = tester.state<SystemBillingScreenState>(
      find.byType(SystemBillingScreen),
    );
    await runAsyncAndPump(tester, () => state.initialised);
    await pumpReadOnlyFutureBuilders(tester, find.byType(SystemBillingScreen));
    await saveCapture(tester, key, 'billing-save-main');
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await saveCapture(tester, key, 'billing-logo-main');
    await unmount(tester);
  });

  testWidgets('capture task photo controls', (tester) async {
    await prepareCapture(tester);
    final (job, task) = await sampleTask(tester);
    final key = GlobalKey();
    await mount(
      tester,
      key,
      TaskEditScreen(job: job, task: task),
      wrapHome: false,
    );
    await pumpUntilFound(tester, find.byIcon(Icons.camera_alt));
    await pumpReadOnlyFutureBuilders(tester, find.byType(TaskEditScreen));
    await tester.ensureVisible(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    await saveCapture(tester, key, 'task-photos-main');
    await unmount(tester);
  });

  testWidgets('capture start, active timer and stop review', (tester) async {
    await prepareCapture(tester);
    final (job, task) = await sampleTask(tester);
    final key = GlobalKey();
    await mount(
      tester,
      key,
      TaskListScreen(parent: Parent(job), extended: true),
    );
    await pumpUntilFound(tester, find.byTooltip('Start task timer'));
    await pumpReadOnlyFutureBuilders(tester, find.byType(TaskListScreen));
    await saveCapture(tester, key, 'timer-start-main');
    // Seed a running timer and task state for this sample.
    // These captures do not exercise timer-start side effects.
    await runAsyncAndPump(tester, () async {
      final entry = TimeEntry.forInsert(
        taskId: task.id,
        startTime: DateTime.now().subtract(const Duration(minutes: 25)),
      );
      await DaoTimeEntry().insert(entry);
      await DaoTask().update(task.copyWith(status: TaskStatus.inProgress));
      June.getState<ActiveTimeEntryState>(
        ActiveTimeEntryState.new,
      ).setActiveTimeEntry(entry, task);
    });
    await unmount(tester);
    await mount(
      tester,
      key,
      TaskListScreen(parent: Parent(job), extended: true),
    );
    await pumpUntilFound(tester, find.byTooltip('Stop task timer'));
    await pumpReadOnlyFutureBuilders(tester, find.byType(HomeScaffold));
    await saveCapture(tester, key, 'timer-active-main');
    await tester.tap(find.byTooltip('Stop task timer').first);
    await pumpUntilFound(tester, find.text('Stop timer'));
    await tester.pumpAndSettle();
    await saveCapture(tester, key, 'timer-stop-main');
    await unmount(tester);
  });
}

Future<(Job, Task)> sampleTask(WidgetTester tester) async {
  late Job job;
  late Task task;
  await tester.runAsync(() async {
    job = await createJobWithCustomer(
      billingType: BillingType.timeAndMaterial,
      hourlyRate: MoneyEx.dollars(75),
      status: JobStatus.inProgress,
      summary: 'Repair demo gate',
    );
    task = Task.forInsert(
      jobId: job.id,
      name: 'Replace demo hinges',
      description: 'Sample task for the HMB manual.',
      status: TaskStatus.approved,
    );
    await DaoTask().insert(task);
  });
  return (job, task);
}

Future<void> prepareCapture(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final root = Platform.environment['FLUTTER_ROOT']!;
  await tester.runAsync(() async {
    final loader = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
  });
}

ThemeData captureTheme() {
  final theme = HMBTheme.dark;
  return theme.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: theme.elevatedButtonTheme.style?.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => theme.elevatedButtonTheme.style?.textStyle
              ?.resolve(states)
              ?.copyWith(fontFamily: 'Roboto'),
        ),
      ),
    ),
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
    dialogTheme: theme.dialogTheme.copyWith(
      titleTextStyle: theme.dialogTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
      contentTextStyle: theme.dialogTheme.contentTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
  );
}

Future<void> mount(
  WidgetTester tester,
  GlobalKey key,
  Widget page, {
  bool wrapHome = true,
}) => tester.pumpWidget(
  RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: captureTheme(),
      home: wrapHome ? HomeScaffold(initialScreen: page) : page,
    ),
  ),
);

Future<void> saveCapture(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  await tester.pump();
  expect(tester.takeException(), isNull);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'doc/manual-refresh/images/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(seconds: 1));
}
