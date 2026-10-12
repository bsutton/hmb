import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/product_catalog/demo_product_catalog.dart';
import 'package:hmb/api/product_catalog/product_catalog.dart';
import 'package:hmb/api/product_catalog/product_search_controller.dart';

void main() {
  const catalog = DemoProductCatalog();
  test(
    'search matches description words and returns honest optional data',
    () async {
      expect(
        (await catalog.search('repair timber')).map((p) => p.id),
        contains('DEMO-TIMBER'),
      );
      expect(await catalog.search('xyzzy'), isEmpty);
      final entries = await catalog.availability('DEMO-PAINT');
      expect(entries[0].quantity, 12);
      expect(entries[1].quantity, isNull);
      expect(entries[1].stockLabel, contains('quantity unknown'));
      expect(entries[2].hasStock, isFalse);
      expect(entries[2].locationLabel, 'Aisle / bay unknown');
      expect(await catalog.availability('invalid'), isEmpty);
      expect(
        DemoProductCatalog.products.last.priceLabel,
        'Sample price unavailable',
      );
    },
  );

  test('distance sorting changes for sample home/current', () {
    List<String> nearest(CatalogPoint point) {
      final stores = [...DemoProductCatalog.sampleStores]
        ..sort(
          (a, b) =>
              point.distanceKm(a.point).compareTo(point.distanceKm(b.point)),
        );
      return stores.map((s) => s.id).toList();
    }

    expect(nearest(DemoProductCatalog.home).first, 'demo-north');
    expect(nearest(DemoProductCatalog.current).first, 'demo-east');
    expect(DemoProductCatalog.home.distanceKm(DemoProductCatalog.home), 0);
  });

  test('selection preserves text and marks any inserted fields as demo', () {
    final selection = ProductSelection(
      DemoProductCatalog.products.first,
      DemoProductCatalog.sampleStores.first,
    );
    expect(
      selection.fillEmptyDescription('My special paint'),
      'My special paint',
    );
    expect(selection.fillEmptyDescription(''), startsWith('[DEMO]'));
    final purpose = selection.appendToPurpose('Existing notes');
    expect(purpose, startsWith('Existing notes\n[DEMO product DEMO-PAINT]'));
    expect(selection.appendToPurpose(purpose), purpose);
    expect(purpose, isNot(contains('48.00')));
  });

  testWidgets('debounce, stale success/error, clearing and disposal', (
    tester,
  ) async {
    final catalog = PendingCatalog();
    final controller = ProductSearchController(catalog)..search('pa');
    await tester.pump(const Duration(milliseconds: 200));
    controller.search('paint');
    await tester.pump(const Duration(milliseconds: 350));
    expect(catalog.requests.keys, ['paint']);
    controller.search('timber');
    catalog.requests['paint']!.complete([DemoProductCatalog.products.first]);
    await tester.pump();
    expect(controller.results, isEmpty);
    await tester.pump(const Duration(milliseconds: 350));
    controller.search('screws');
    catalog.requests['timber']!.completeError(StateError('old request'));
    await tester.pump();
    expect(controller.error, isNull);
    await tester.pump(const Duration(milliseconds: 350));
    catalog.requests['screws']!.complete([DemoProductCatalog.products[2]]);
    await tester.pump();
    expect(controller.results.single.id, 'DEMO-SCREW');
    controller.search('');
    expect(controller.results, isEmpty);
    expect(controller.busy, isFalse);
    controller
      ..search('gone', immediate: true)
      ..dispose();
    catalog.requests['gone']!.completeError(StateError('disposed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure is visible and retry succeeds', (tester) async {
    final catalog = PendingCatalog();
    final controller = ProductSearchController(catalog)
      ..search('paint', immediate: true);
    catalog.requests['paint']!.completeError(StateError('network'));
    await tester.pump();
    expect(controller.error, isNotNull);
    expect(controller.busy, isFalse);
    controller.search('paint', immediate: true);
    catalog.requests['paint']!.complete([]);
    await tester.pump();
    expect(controller.error, isNull);
    expect(controller.results, isEmpty);
    controller.dispose();
  });
}

class PendingCatalog implements ProductCatalog {
  final requests = <String, Completer<List<CatalogProduct>>>{};

  @override
  Future<List<CatalogProduct>> search(String query) =>
      (requests[query] = Completer<List<CatalogProduct>>()).future;
  @override
  Future<List<CatalogStore>> stores() async => [];
  @override
  Future<List<StoreProduct>> availability(String productId) async => [];
}
