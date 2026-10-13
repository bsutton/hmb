import 'product_catalog.dart';

/// Fictional catalogue: no network, real brands, addresses or retailer images.
class DemoProductCatalog implements ProductCatalog {
  const DemoProductCatalog();

  static const home = CatalogPoint(-37.80, 144.96);
  static const current = CatalogPoint(-37.84, 145.02);
  static const sampleStores = [
    CatalogStore(
      'demo-north',
      'Demo North warehouse',
      CatalogPoint(-37.78, 144.96),
    ),
    CatalogStore(
      'demo-east',
      'Demo East warehouse',
      CatalogPoint(-37.83, 145.04),
    ),
    CatalogStore(
      'demo-west',
      'Demo West warehouse',
      CatalogPoint(-37.81, 144.89),
    ),
  ];
  static const products = [
    CatalogProduct(
      id: 'DEMO-PAINT',
      name: 'Interior wall paint 4 L',
      details: 'Fictional water-based low-sheen paint. Sample colour: white.',
      illustration: ProductIllustration.paint,
      priceCents: 4800,
    ),
    CatalogProduct(
      id: 'DEMO-TIMBER',
      name: 'Pine timber 90 × 35 mm',
      details: 'Fictional framing timber. Sample length: 2.4 m.',
      illustration: ProductIllustration.timber,
      priceCents: 1250,
    ),
    CatalogProduct(
      id: 'DEMO-SCREW',
      name: 'Timber screws 50 mm · 100 pack',
      details: 'Fictional countersunk screws for a timber repair.',
      illustration: ProductIllustration.screw,
      priceCents: 1590,
    ),
    CatalogProduct(
      id: 'DEMO-SEALANT',
      name: 'Flexible sealant 300 mL',
      details: 'Fictional white gap filler for interior trim.',
      illustration: ProductIllustration.sealant,
      priceCents: 850,
    ),
    CatalogProduct(
      id: 'DEMO-BRUSH',
      name: 'Paint brush 50 mm',
      details: 'Fictional synthetic brush for painting walls and trim.',
      illustration: ProductIllustration.brush,
      priceCents: 990,
    ),
    CatalogProduct(
      id: 'DEMO-BOARD',
      name: 'Plasterboard sheet 2400 × 1200 mm',
      details: 'Fictional 10 mm board for lining an internal wall.',
      illustration: ProductIllustration.board,
    ),
  ];

  @override
  Future<List<CatalogProduct>> search(String query) async {
    final words = query.toLowerCase().trim().split(RegExp(r'\s+'));
    if (query.trim().isEmpty) {
      return products;
    }
    return products.where((product) {
      final text = '${product.name} ${product.details} ${product.id}'
          .toLowerCase();
      return words.any((word) => word.length >= 2 && text.contains(word));
    }).toList();
  }

  @override
  Future<List<CatalogStore>> stores() async => sampleStores;

  @override
  Future<List<StoreProduct>> availability(String productId) async {
    final index = products.indexWhere((product) => product.id == productId);
    if (index < 0) {
      return [];
    }
    return [
      StoreProduct(
        store: sampleStores[0],
        stock: ProductStock.available,
        quantity: index.isEven ? 12 : null,
        aisle: '4',
        bay: '2',
      ),
      StoreProduct(
        store: sampleStores[1],
        stock: index.isEven ? ProductStock.available : ProductStock.unavailable,
        aisle: '9',
        bay: '6',
      ),
      StoreProduct(store: sampleStores[2]),
    ];
  }
}
