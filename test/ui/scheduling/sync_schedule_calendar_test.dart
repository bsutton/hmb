@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/integrations/google_calendar/google_calendar_sync.dart';
import 'package:hmb/ui/scheduling/sync_schedule_calendar.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:toastification/toastification.dart';

void main() {
  Future<void> showSync(
    WidgetTester tester, {
    required Future<ExternalCalendarSyncResult> Function() operation,
    required Future<void> Function() signIn,
  }) async {
    await tester.pumpWidget(
      ToastificationWrapper(
        child: MaterialApp(
          builder: (context, child) =>
              Stack(children: [child!, const BlockingOverlay()]),
          home: Scaffold(
            body: Builder(
              builder: (context) => HMBButtonPrimary(
                label: 'Save schedule',
                hint: 'Save the schedule change',
                onPressed: () => syncScheduleWithGoogleCalendar(
                  context,
                  operation,
                  signIn: signIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();
  }

  Future<void> disposeSync(WidgetTester tester) async {
    toastification.dismissAll();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets('offers sign-in and retries the saved change once', (
    tester,
  ) async {
    var syncCalls = 0;
    var signInCalls = 0;
    await showSync(
      tester,
      operation: () async => ++syncCalls == 1
          ? ExternalCalendarSyncResult.signInRequired
          : ExternalCalendarSyncResult.synced,
      signIn: () async {
        signInCalls++;
      },
    );
    expect(find.text('Sign in to Google Calendar?'), findsOneWidget);
    expect(signInCalls, 0);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(signInCalls, 1);
    expect(syncCalls, 2);
    expect(find.text('Sign in to Google Calendar?'), findsNothing);
    await disposeSync(tester);
  });

  testWidgets('declining does not sign in or retry', (tester) async {
    var syncCalls = 0;
    var signInCalls = 0;
    await showSync(
      tester,
      operation: () async {
        syncCalls++;
        return ExternalCalendarSyncResult.signInRequired;
      },
      signIn: () async {
        signInCalls++;
      },
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(signInCalls, 0);
    expect(syncCalls, 1);
    await disposeSync(tester);
  });

  for (final result in [
    ExternalCalendarSyncResult.synced,
    ExternalCalendarSyncResult.disabled,
    ExternalCalendarSyncResult.unavailable,
  ]) {
    testWidgets('$result does not request sign-in', (tester) async {
      var signInCalls = 0;
      await showSync(
        tester,
        operation: () async => result,
        signIn: () async {
          signInCalls++;
        },
      );
      expect(find.text('Sign in to Google Calendar?'), findsNothing);
      expect(signInCalls, 0);
      await disposeSync(tester);
    });
  }

  testWidgets('cancelled Google sign-in does not loop', (tester) async {
    var syncCalls = 0;
    await showSync(
      tester,
      operation: () async {
        syncCalls++;
        return ExternalCalendarSyncResult.signInRequired;
      },
      signIn: () async {},
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(syncCalls, 2);
    expect(find.text('Sign in to Google Calendar?'), findsNothing);
    expect(find.textContaining('sign-in was not completed'), findsOneWidget);
    await disposeSync(tester);
  });

  testWidgets('retry failure reports the saved local change', (tester) async {
    var syncCalls = 0;
    await showSync(
      tester,
      operation: () async {
        if (++syncCalls == 1) {
          return ExternalCalendarSyncResult.signInRequired;
        }
        throw StateError('Calendar unavailable');
      },
      signIn: () async {},
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(syncCalls, 2);
    expect(find.textContaining('Schedule saved, but'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeSync(tester);
  });
}
