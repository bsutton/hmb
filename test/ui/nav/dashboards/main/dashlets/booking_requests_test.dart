@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_booking_request.dart';
import 'package:hmb/entity/booking_request.dart';
import 'package:hmb/ui/nav/dashboards/dashboard.dart';
import 'package:hmb/ui/nav/dashboards/main/dashlets/booking_requests.dart';
import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../database/management/db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  for (final brightness in Brightness.values) {
    testWidgets('pending request bell updates and clears in $brightness', (
      tester,
    ) async {
      final theme = ThemeData(brightness: brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: BookingRequestsDashlet(),
            ),
          ),
        ),
      );
      Future<void> refresh() async {
        June.getState(DashboardReloaded.new).setState();
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
      }

      Color? bellColor() =>
          tester.widget<Icon>(find.byIcon(Icons.notification_important)).color;
      await refresh();
      expect(bellColor(), theme.colorScheme.primary);
      expect(find.text('All caught up'), findsOneWidget);

      final request = BookingRequest.forInsert(
        remoteId: 'bell-test',
        status: BookingRequestStatus.pending,
        name: 'Example',
        businessName: '',
        firstName: 'Example',
        surname: '',
        email: '',
        phone: '',
        description: '',
        street: '',
        suburb: '',
        day1: '',
        day2: '',
        day3: '',
      );
      await tester.runAsync(() => DaoBookingRequest().insert(request));
      await refresh();
      expect(
        bellColor(),
        brightness == Brightness.dark
            ? Colors.amber.shade300
            : Colors.amber.shade900,
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Tap to review'), findsOneWidget);

      await tester.runAsync(() => DaoBookingRequest().markImported(request));
      await refresh();
      expect(bellColor(), theme.colorScheme.primary);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      await tester.runAsync(
        () => DaoBookingRequest().update(
          request.copyWith(status: BookingRequestStatus.rejected),
        ),
      );
      await refresh();
      expect(bellColor(), theme.colorScheme.primary);
    });
  }
}
