import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/product_catalog/catalog_preferences.dart';
import 'package:hmb/ui/product_catalog/product_search_screen.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../../tool/product_catalog_preview.dart';

/// Optional rendered UI evidence, independent of native app build toolchains.
/// Run with --dart-define=CAPTURE_PRODUCT_DEMO=true and HMB_PREVIEW_FONT set
/// to a local Roboto-Regular.ttf from the Flutter SDK material_fonts directory.
void main() {
  testWidgets('capture fixture product search and estimator previews', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() async {
      final font = File(Platform.environment['HMB_PREVIEW_FONT']!);
      final loader = FontLoader('DemoRoboto')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
      final icons = File('${font.parent.path}/MaterialIcons-Regular.otf');
      final iconLoader = FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await iconLoader.load();
    });

    Future<void> mount(Widget home, Size size, {double scale = 1}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: HMBTheme.dark.copyWith(
            textTheme: HMBTheme.dark.textTheme.apply(fontFamily: 'DemoRoboto'),
            primaryTextTheme: HMBTheme.dark.primaryTextTheme.apply(
              fontFamily: 'DemoRoboto',
            ),
            appBarTheme: HMBTheme.dark.appBarTheme.copyWith(
              titleTextStyle: HMBTheme.dark.textTheme.titleLarge!.copyWith(
                fontFamily: 'DemoRoboto',
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: HMBTheme.dark.elevatedButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'DemoRoboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: boundaryKey, child: child),
          ),
          home: home,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/bunnings-validation/screenshots');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await mount(const CatalogPreview(), const Size(1000, 1200));
    await capture('estimator-desktop');
    await mount(
      ProductSearchScreen(
        initialQuery: 'paint',
        preferences: MemoryCatalogPreferences(),
      ),
      const Size(1000, 1000),
    );
    await capture('search-desktop');
    await tester.tap(find.text('Details and stores').first);
    await tester.pumpAndSettle();
    await capture('product-store-desktop');

    await mount(
      ProductSearchScreen(
        initialQuery: 'paint',
        preferences: MemoryCatalogPreferences(),
      ),
      const Size(390, 844),
    );
    await capture('search-phone');
    await tester.tap(find.text('Details and stores').first);
    await tester.pumpAndSettle();
    await capture('product-store-phone');
    await tester.scrollUntilVisible(
      find.text('Use demo product'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('nearby-stores-phone');

    await mount(const CatalogPreview(), const Size(320, 800), scale: 2);
    await tester.scrollUntilVisible(
      find.text('Review DEMO-PAINT'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('estimator-phone-200-percent');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Unit cost'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('estimator-phone-pricing-with-keyboard');
    // Opt-in evidence capture is intentionally excluded from normal test runs.
    // ignore: do_not_use_environment
  }, skip: !const bool.fromEnvironment('CAPTURE_PRODUCT_DEMO'));
}
