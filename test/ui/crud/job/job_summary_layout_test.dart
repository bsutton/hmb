@Tags(['flutter'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/main.dart' as app;
import 'package:hmb/ui/crud/job/edit_job_screen.dart';
import 'package:hmb/ui/crud/job/job_parties_screen.dart';
import 'package:hmb/ui/widgets/widgets.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:material_ui/material_ui.dart';

import '../../../database/management/db_utility_test_helper.dart';
import '../../ui_test_helpers.dart';
import 'job_summary_editor_test.dart' show pumpUntil;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Optional font for local screenshot review; ordinary tests use Ahem.
    // ignore: do_not_use_environment
    const fontPath = String.fromEnvironment('HMB_VISUAL_FONT');
    if (fontPath.isNotEmpty) {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(bytes.buffer.asByteData()))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final width in [360.0, 1200.0]) {
    for (final parties in [false, true]) {
      testWidgets('${parties ? 'parties' : 'summary'} at $width', (
        tester,
      ) async {
        late Job job;
        await tester.runAsync(() async {
          await setupTestDb();
          job = await createJobWithCustomer(
            billingType: BillingType.timeAndMaterial,
            hourlyRate: MoneyEx.dollars(95),
            summary: 'Apartment repairs',
          );
        });
        addTearDown(tearDownTestDb);
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (_, child) =>
                Stack(children: [child!, const BlockingOverlay()]),
            home: parties
                ? JobPartiesScreen(job: job, editCustomers: () async {})
                : JobEditScreen(job: job),
          ),
        );
        await pumpUntil(tester, find.text(parties ? 'Add party' : 'Manage'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!parties) {
          await pumpUntil(tester, find.text('Next: none'));
          expect(find.text('Schedule'), findsOneWidget);
          expect(find.text('Next: none'), findsOneWidget);
        }
        for (final element in find.byType(SurfaceCardWithActions).evaluate()) {
          expect(
            tester.getSize(find.byWidget(element.widget)).width,
            lessThanOrEqualTo(800),
          );
        }
        final action = find.text(parties ? 'Add party' : 'Manage');
        expect(tester.getSize(action).width, lessThan(150));
        // Opt-in local visual checks; generated images stay out of Git.
        // ignore: do_not_use_environment
        if (const bool.fromEnvironment('HMB_CAPTURE_UI')) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../../../build/job-${parties ? 'parties' : 'summary'}'
              '-${width.toInt()}.png',
            ),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
