@Tags(['flutter'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/nav/dashboards/accounting/accounting_reports_dashboard.dart';
import 'package:hmb/ui/nav/dashboards/integration/integration_dashboard.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final entry in <String, Widget>{
    'integrations': const IntegrationDashboardPage(),
    'accounting-reports': const AccountingReportsDashboardPage(),
  }.entries) {
    testWidgets('capture ${entry.key} without accounts', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
      await tester.runAsync(() async {
        // Flutter tests default to Ahem; use Android's real Roboto glyphs.
        for (final family in ['Roboto']) {
          final loader = FontLoader(family);
          for (final weight in ['Regular', 'Medium', 'Bold']) {
            loader.addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
                  ).readAsBytesSync(),
                ),
              ),
            );
          }
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          );
        await icons.load();
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: HMBTheme.dark.copyWith(
            textTheme: HMBTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
            primaryTextTheme: HMBTheme.dark.primaryTextTheme.apply(
              fontFamily: 'Roboto',
            ),
            appBarTheme: HMBTheme.dark.appBarTheme.copyWith(
              titleTextStyle: HMBTheme.dark.appBarTheme.titleTextStyle
                  ?.copyWith(fontFamily: 'Roboto'),
            ),
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  entry.key == 'integrations'
                      ? 'Integrations'
                      : 'Accounting Reports',
                ),
              ),
              body: entry.value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'doc/manual-refresh/images/${entry.key}-main.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
