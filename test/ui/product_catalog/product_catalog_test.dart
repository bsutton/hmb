import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/product_catalog/catalog_preferences.dart';
import 'package:hmb/api/product_catalog/demo_product_catalog.dart';
import 'package:hmb/ui/product_catalog/product_search_screen.dart';
import 'package:hmb/ui/product_catalog/product_store_screen.dart';
import 'package:hmb/ui/product_catalog/task_product_picker.dart';
import 'package:hmb/ui/widgets/layout/hmb_form_section.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1000, 1800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: HMBTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('store switching updates stock/location and saves default', (
    tester,
  ) async {
    final preferences = MemoryCatalogPreferences();
    await mount(
      tester,
      ProductStoreScreen(
        product: DemoProductCatalog.products.first,
        catalog: const DemoProductCatalog(),
        preferences: preferences,
      ),
    );
    expect(find.text('Selected: Demo North warehouse'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('choose-demo-east')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('choose-demo-east')));
    await tester.pumpAndSettle();
    expect(find.text('Selected: Demo East warehouse'), findsOneWidget);
    expect(find.text('Sample in stock · quantity unknown'), findsNWidgets(2));
    expect(find.text('Sample aisle 9 · bay 6'), findsNWidgets(2));
    await tester.tap(find.text('Save as default store'));
    await tester.pumpAndSettle();
    expect(preferences.defaultStore, 'demo-east');
    await mount(
      tester,
      ProductStoreScreen(
        key: const ValueKey('reopened'),
        product: DemoProductCatalog.products.first,
        catalog: const DemoProductCatalog(),
        preferences: preferences,
      ),
    );
    expect(find.text('Selected: Demo East warehouse'), findsOneWidget);
  });

  testWidgets('location permission preview has fallback and new ordering', (
    tester,
  ) async {
    await mount(
      tester,
      ProductStoreScreen(
        product: DemoProductCatalog.products.first,
        catalog: const DemoProductCatalog(),
        preferences: MemoryCatalogPreferences(),
      ),
    );
    await tester.tap(find.text('Use my location (preview)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Location denied in preview'), findsOneWidget);
    await tester.tap(find.text('Use my location (preview)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use sample current location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Near sample current location'), findsOneWidget);
    final storeNames = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => text.contains(' km'))
        .toList();
    expect(storeNames.first, startsWith('Demo East warehouse'));
  });

  testWidgets('explicit picker selection keeps user text', (tester) async {
    final description = TextEditingController(text: 'paint');
    final purpose = TextEditingController(text: 'Keep these notes');
    addTearDown(description.dispose);
    addTearDown(purpose.dispose);
    await mount(
      tester,
      Scaffold(
        body: HMBFormList(
          children: [
            TaskProductPicker(
              description: description,
              purpose: purpose,
              preferences: MemoryCatalogPreferences(),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Find a product (demo)'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(purpose.text, 'Keep these notes');
    await tester.tap(find.text('Details and stores').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use demo product'));
    await tester.pumpAndSettle();
    expect(description.text, 'paint');
    expect(purpose.text, startsWith('Keep these notes\n[DEMO product'));
  });

  testWidgets('search empty state and phone at 200% have no overflow', (
    tester,
  ) async {
    await mount(
      tester,
      ProductSearchScreen(
        initialQuery: 'zzzz',
        preferences: MemoryCatalogPreferences(),
      ),
      size: const Size(320, 800),
      scale: 2,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('No sample products match'),
      200,
        scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No sample products match'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mount(
      tester,
      ProductStoreScreen(
        product: DemoProductCatalog.products.first,
        catalog: const DemoProductCatalog(),
        preferences: MemoryCatalogPreferences(),
      ),
      size: const Size(320, 800),
      scale: 2,
    );
    await tester.scrollUntilVisible(find.text('Use demo product'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
