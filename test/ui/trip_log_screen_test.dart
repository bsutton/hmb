import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmb/dao/dao_trip_log.dart';
import 'package:hmb/ui/tools/trip_log_screen.dart';
import 'package:hmb/ui/tools/trip_log_settings_screen.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

import '../database/management/db_utility_test_helper.dart';
import 'ui_test_helpers.dart';

void main() {
  testWidgets('trip log starts off and supports custom reporting dates', (
    tester,
  ) async {
    await tester.runAsync(setupTestDb);
    addTearDown(tearDownTestDb);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Stack(children: [child!, const BlockingOverlay()]),
        home: const TripLogScreen(),
      ),
    );
    await pumpUntilFound(tester, find.text('Trip logging is off'));
    tester
        .widget<HMBDroplist<String>>(find.byType(HMBDroplist<String>))
        .onChanged('Custom');
    await pumpUntilFound(tester, find.byType(HMBDateTimeField));
    expect(find.byType(HMBDateTimeField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('trip settings scroll and validate at 320px, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(setupTestDb);
      addTearDown(tearDownTestDb);
      const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
      final messenger = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          locationChannel,
          (call) async => switch (call.method) {
            'isLocationServiceEnabled' => false,
            'checkPermission' => 0,
            _ => throw StateError(
              'Unexpected location request: ${call.method}',
            ),
          },
        );
      addTearDown(
        () => messenger.setMockMethodCallHandler(locationChannel, null),
      );
      final router = GoRouter(
        initialLocation: '/home/tools/trips',
        routes: [
          GoRoute(
            path: '/home/tools/trips',
            builder: (_, _) => const TripLogScreen(),
          ),
          GoRoute(
            path: '/home/tools/trips/settings',
            builder: (_, _) => const TripLogSettingsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ToastificationWrapper(
          child: MaterialApp.router(
            routerConfig: router,
            theme: HMBTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Stack(children: [child!, const BlockingOverlay()]),
            ),
          ),
        ),
      );
      await pumpUntilFound(tester, find.text('Trip logging is off'));
      // Settings moved out of the log into a routed screen. Exercise the
      // actual navigation rather than looking for the retired inline form.
      await tester.tap(find.byTooltip('Trip logging settings'));
      await pumpUntilFound(tester, find.text('Enable trip logging'));
      await tester.tap(find.byTooltip('Record trips when you use HMB'));
      await tester.pumpAndSettle();
      final rate = find.byWidgetPredicate(
        (widget) =>
            widget is HMBTextField &&
            widget.labelText == 'Cost per km (business currency)',
      );
      await tester.scrollUntilVisible(
        rate,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Validation must run before any location permission or network work.
      for (final invalid in ['-1', 'NaN', 'Infinity']) {
        await tester.enterText(rate, invalid);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a non-negative rate'), findsOneWidget);
        expect(find.byType(TripLogSettingsScreen), findsOneWidget);
        final settings = await tester.runAsync(() => DaoTripLog().settings());
        expect(settings!.enabled, isFalse);
        expect(settings.rateCentsPerKm, 0);
        toastification.dismissAll();
        await tester.pumpAndSettle();
      }
      // Cancelling the settings edit returns to the scrollable trip summary.
      await tester.tap(find.text('Cancel'));
      await pumpUntilFound(tester, find.text('Trip logging is off'));
      await tester.scrollUntilVisible(
        find.text('No trips in this period.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No trips in this period.').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Retry unknown distances'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
