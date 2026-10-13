import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/product_catalog/catalog_preferences.dart';
import 'package:hmb/api/product_catalog/demo_product_catalog.dart';
import 'package:hmb/api/product_catalog/product_catalog.dart';
import 'package:hmb/ui/product_catalog/product_suggestions.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/layout/hmb_form_section.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late TextEditingController description;
  late TextEditingController purpose;
  late TextEditingController quantity;
  late TextEditingController price;
  setUp(() {
    description = TextEditingController();
    purpose = TextEditingController(text: 'Keep my notes');
    quantity = TextEditingController(text: '7');
    price = TextEditingController(text: '23.45');
  });
  tearDown(() {
    description.dispose();
    purpose.dispose();
    quantity.dispose();
    price.dispose();
  });

  Future<void> mount(WidgetTester tester, {ProductCatalog? catalog}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: HMBTheme.dark,
        home: Scaffold(
          body: HMBFormList(
            children: [
              HMBTextField(controller: description, labelText: 'Description'),
              ProductSuggestions(
                description: description,
                purpose: purpose,
                catalog: catalog ?? const DemoProductCatalog(),
                preferences: MemoryCatalogPreferences(),
              ),
              HMBTextField(controller: purpose, labelText: 'Purpose'),
              HMBTextField(controller: quantity, labelText: 'Quantity'),
              HMBTextField(controller: price, labelText: 'Unit cost'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'suggestions do not write fields; review and select is deliberate',
    (tester) async {
      await mount(tester);
      description.text = 'paint';
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Review DEMO-PAINT'), findsOneWidget);
      expect(purpose.text, 'Keep my notes');
      expect(quantity.text, '7');
      expect(price.text, '23.45');
      await tester.tap(find.text('Review DEMO-PAINT'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(purpose.text, 'Keep my notes');
      await tester.tap(find.text('Review DEMO-PAINT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use demo product'));
      await tester.pumpAndSettle();
      expect(description.text, 'paint');
      expect(
        purpose.text,
        startsWith('Keep my notes\n[DEMO product DEMO-PAINT]'),
      );
      expect(quantity.text, '7');
      expect(price.text, '23.45');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'hiding invalidates pending work; reshow uses latest description',
    (tester) async {
      final pending = ControlledCatalog();
      await mount(tester, catalog: pending);
      description.text = 'paint';
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Finding sample suggestions'), findsOneWidget);
      await tester.tap(find.text('Hide suggestions'));
      description.text = 'timber';
      pending.requests['paint']!.complete([DemoProductCatalog.products.first]);
      await tester.pumpAndSettle();
      expect(find.text('Review DEMO-PAINT'), findsNothing);
      expect(pending.requests.keys, ['paint']);
      await tester.tap(find.text('Show suggestions'));
      await tester.pump(const Duration(milliseconds: 400));
      pending.requests['timber']!.complete([DemoProductCatalog.products[1]]);
      await tester.pumpAndSettle();
      expect(find.text('Review DEMO-TIMBER'), findsOneWidget);
      description.text = '';
      await tester.pumpAndSettle();
      expect(find.text('Review DEMO-TIMBER'), findsNothing);
      expect(purpose.text, 'Keep my notes');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('error and retry recover without changing form values', (
    tester,
  ) async {
    final pending = ControlledCatalog();
    await mount(tester, catalog: pending);
    description.text = 'paint';
    await tester.pump(const Duration(milliseconds: 400));
    pending.requests['paint']!.completeError(StateError('fixture failure'));
    await tester.pumpAndSettle();
    expect(find.text('Retry suggestions'), findsOneWidget);
    await tester.tap(find.text('Retry suggestions'));
    pending.requests['paint']!.complete([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('No sample suggestions'), findsOneWidget);
    expect(description.text, 'paint');
    expect(purpose.text, 'Keep my notes');
    expect(quantity.text, '7');
    expect(price.text, '23.45');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class ControlledCatalog extends DemoProductCatalog {
  final requests = <String, Completer<List<CatalogProduct>>>{};

  @override
  Future<List<CatalogProduct>> search(String query) =>
      (requests[query] = Completer<List<CatalogProduct>>()).future;
}
