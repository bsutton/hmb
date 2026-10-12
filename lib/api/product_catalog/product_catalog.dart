import 'dart:math' as math;

/// Provider-neutral values. Missing data must stay missing, especially stock.
enum ProductStock { available, unavailable, unknown }

enum ProductIllustration { paint, timber, screw, sealant, brush, board }

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.details,
    required this.illustration,
    this.priceCents,
  });

  final String id;
  final String name;
  final String details;
  final ProductIllustration illustration;
  final int? priceCents;

  String get priceLabel => priceCents == null
      ? 'Sample price unavailable'
      : 'Sample AUD \$${(priceCents! / 100).toStringAsFixed(2)}';
}

class CatalogPoint {
  const CatalogPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  /// Great-circle distance, not driving distance.
  double distanceKm(CatalogPoint other) {
    const radians = math.pi / 180;
    final lat = (other.latitude - latitude) * radians;
    final lon = (other.longitude - longitude) * radians;
    final a =
        math.pow(math.sin(lat / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(other.latitude * radians) *
            math.pow(math.sin(lon / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class CatalogStore {
  const CatalogStore(this.id, this.name, this.point);
  final String id;
  final String name;
  final CatalogPoint point;
}

class StoreProduct {
  const StoreProduct({
    required this.store,
    this.stock = ProductStock.unknown,
    this.quantity,
    this.aisle,
    this.bay,
  }) : assert(quantity == null || quantity >= 0, 'Quantity cannot be negative');

  final CatalogStore store;
  final ProductStock stock;
  final int? quantity;
  final String? aisle;
  final String? bay;

  String get stockLabel => quantity != null
      ? 'Sample quantity: $quantity'
      : switch (stock) {
          ProductStock.available => 'Sample in stock · quantity unknown',
          ProductStock.unavailable => 'Sample out of stock',
          ProductStock.unknown => 'Stock unknown · quantity unknown',
        };

  String get locationLabel => [
    if (aisle != null) 'Sample aisle $aisle',
    if (bay != null) 'bay $bay',
    if (aisle == null && bay == null) 'Aisle / bay unknown',
  ].join(' · ');

  bool get hasStock =>
      quantity != null ? quantity! > 0 : stock == ProductStock.available;
}

/// No live provider is registered. A future adapter needs approved access and
/// verified inventory, pricing, location and media contracts first.
abstract interface class ProductCatalog {
  Future<List<CatalogProduct>> search(String query);
  Future<List<CatalogStore>> stores();
  Future<List<StoreProduct>> availability(String productId);
}

class ProductSelection {
  const ProductSelection(this.product, this.store);
  final CatalogProduct product;
  final CatalogStore store;

  String get reference =>
      '[DEMO product ${product.id}] ${product.name} — ${store.name}';

  /// Explicit selection appends a reference, preserving all user text.
  String appendToPurpose(String purpose) => purpose.contains(reference)
      ? purpose
      : '${purpose.isEmpty ? '' : '$purpose\n'}$reference';

  String fillEmptyDescription(String description) =>
      description.trim().isEmpty ? '[DEMO] ${product.name}' : description;
}
