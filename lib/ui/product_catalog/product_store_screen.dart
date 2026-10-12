import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/product_catalog/catalog_preferences.dart';
import '../../api/product_catalog/demo_product_catalog.dart';
import '../../api/product_catalog/product_catalog.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toggle.dart';
import '../widgets/layout/hmb_empty.dart';
import '../widgets/layout/hmb_form_section.dart';
import '../widgets/layout/hmb_full_page_child_screen.dart';
import '../widgets/layout/surface.dart';
import 'product_card.dart';
import 'product_search_screen.dart';

class ProductStoreScreen extends StatefulWidget {
  const ProductStoreScreen({
    required this.product,
    required this.catalog,
    required this.preferences,
    super.key,
  });
  final CatalogProduct product;
  final ProductCatalog catalog;
  final CatalogPreferences preferences;

  @override
  State<ProductStoreScreen> createState() => _ProductStoreScreenState();
}

class _ProductStoreScreenState extends DeferredState<ProductStoreScreen> {
  List<StoreProduct> _stores = [];
  String? _selectedId;
  String? _defaultId;
  String? _error;
  CatalogPoint _point = DemoProductCatalog.home;
  var _locationStatus = 'Near saved sample home (fictional coordinates).';
  var _onlyStock = false;
  var _saving = false;
  var _loadRevision = 0;

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    final revision = ++_loadRevision;
    try {
      await BlockingUI().runAndWait(() async {
        final stores = await widget.catalog.stores();
        final availability = await widget.catalog.availability(
          widget.product.id,
        );
        final defaultId = await widget.preferences.readDefaultStore();
        if (!mounted || revision != _loadRevision) {
          return;
        }
        _stores = stores
            .map(
              (store) => availability.firstWhere(
                (entry) => entry.store.id == store.id,
                orElse: () => StoreProduct(store: store),
              ),
            )
            .toList();
        _defaultId = defaultId;
        final sorted = _sortedStores;
        _selectedId = _stores.any((store) => store.store.id == defaultId)
            ? defaultId
            : sorted.firstOrNull?.store.id;
        _error = null;
      }, label: 'Finding demo stores');
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        _error = 'Could not load demo stores. Try again.';
      }
    }
  }

  List<StoreProduct> get _sortedStores => [..._stores]
    ..sort(
      (a, b) => _point
          .distanceKm(a.store.point)
          .compareTo(_point.distanceKm(b.store.point)),
    );

  Future<void> _saveDefault() async {
    final id = _selectedId;
    if (id == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await BlockingUI().runAndWait(
        () => widget.preferences.saveDefaultStore(id),
        label: 'Saving default demo store',
      );
      if (mounted) {
        setState(() {
          _defaultId = id;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the default store. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _location() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location permission preview'),
        content: const Text(
          'A live version would ask permission to use your '
          'location to sort nearby stores. This demo never requests device '
          'permission or reads or sends your location. '
          'Choose a simulated outcome.',
        ),
        actions: [
          HMBButtonSecondary(
            label: 'Not now',
            hint: 'Keep saved sample home',
            onPressed: () => Navigator.pop(context),
          ),
          HMBButtonSecondary(
            label: 'Simulate denied',
            hint: 'Preview fallback',
            onPressed: () => Navigator.pop(context, 'denied'),
          ),
          HMBButtonSecondary(
            label: 'Simulate unavailable',
            hint: 'Preview fallback',
            onPressed: () => Navigator.pop(context, 'unavailable'),
          ),
          HMBButtonPrimary(
            label: 'Use sample current location',
            hint: 'Use fictional coordinates only',
            onPressed: () => Navigator.pop(context, 'allowed'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _point = result == 'allowed'
          ? DemoProductCatalog.current
          : DemoProductCatalog.home;
      _locationStatus = result == 'allowed'
          ? 'Near sample current location (fictional coordinates).'
          : 'Location $result in preview. Using saved sample home.';
    });
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Product and stores',
    maxContentWidth: 900,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const HMBEmpty(),
      builder: (context) {
        final selected = _stores
            .where((store) => store.store.id == _selectedId)
            .firstOrNull;
        final sorted = _sortedStores
            .where((store) => !_onlyStock || store.hasStock)
            .toList();
        return HMBFormList(
          children: [
            const Text(catalogDemoNotice),
            ProductPicture(product: widget.product),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(widget.product.details),
            Text('${widget.product.id} · ${widget.product.priceLabel}'),
            if (_error != null) ...[
              Text(_error!),
              HMBButtonSecondary(
                label: 'Retry stores',
                hint: 'Reload demo stores',
                onPressed: () async {
                  await _load();
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ],
            if (selected != null)
              Surface(
                child: HMBFormSection(
                  children: [
                    Text('Selected: ${selected.store.name}'),
                    Text(selected.stockLabel),
                    Text(selected.locationLabel),
                    HMBButtonSecondary(
                      label: _defaultId == _selectedId
                          ? 'Saved default store'
                          : 'Save as default store',
                      onPressed: _saving || _defaultId == _selectedId
                          ? null
                          : () => unawaited(_saveDefault()),
                      hint: 'Remember this demo store for future searches',
                    ),
                    const Text(
                      'Selection adds a labelled demo reference to Purpose. '
                      'Only a blank description is filled. '
                      'Quantity and pricing stay as entered.',
                    ),
                    HMBButtonPrimary(
                      label: 'Use demo product',
                      hint: 'Add this demo reference to the task item',
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProductSelection(widget.product, selected.store)),
                    ),
                  ],
                ),
              ),
            Text(_locationStatus),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                HMBButtonSecondary(
                  label: 'Use my location (preview)',
                  hint: 'Preview permission without reading your location',
                  onPressed: () => unawaited(_location()),
                ),
                HMBButtonSecondary(
                  label: 'Use saved sample home',
                  hint: 'Sort near the fictional home location',
                  onPressed: () => setState(() {
                    _point = DemoProductCatalog.home;
                    _locationStatus =
                        'Near saved sample home (fictional coordinates).';
                  }),
                ),
              ],
            ),
            const Text('Nearby demo stores · straight-line distance'),
            HMBToggle(
              label: 'Only stores with sample stock',
              initialValue: _onlyStock,
              hint: 'Unknown stock is not treated as available',
              onToggled: (value) => setState(() => _onlyStock = value),
            ),
            if (sorted.isEmpty)
              const Text('No matching demo stores. Try showing all stores.'),
            for (final entry in sorted)
              Surface(
                child: HMBFormSection(
                  children: [
                    Text(
                      '${entry.store.name} · '
                      '${_distance(entry)} km',
                    ),
                    Text(entry.stockLabel),
                    Text(entry.locationLabel),
                    HMBButtonSecondary(
                      key: ValueKey('choose-${entry.store.id}'),
                      label: entry.store.id == _selectedId
                          ? 'Selected store'
                          : 'Choose store',
                      hint:
                          'Show stock and aisle / bay for ${entry.store.name}',
                      onPressed: entry.store.id == _selectedId
                          ? null
                          : () => setState(() => _selectedId = entry.store.id),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );

  String _distance(StoreProduct entry) =>
      _point.distanceKm(entry.store.point).toStringAsFixed(1);
}
