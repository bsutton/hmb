import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/product_catalog/catalog_preferences.dart';
import '../../api/product_catalog/demo_product_catalog.dart';
import '../../api/product_catalog/product_catalog.dart';
import '../../api/product_catalog/product_search_controller.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/hmb_form_section.dart';
import '../widgets/layout/surface.dart';
import 'product_card.dart';
import 'product_store_screen.dart';

/// Suggestions never own price/quantity controllers and never apply a result
/// merely because it arrived. The user reviews a product and store first.
class ProductSuggestions extends StatefulWidget {
  const ProductSuggestions({
    required this.description,
    required this.purpose,
    this.catalog = const DemoProductCatalog(),
    this.preferences = const SavedCatalogPreferences(),
    super.key,
  });

  final TextEditingController description;
  final TextEditingController purpose;
  final ProductCatalog catalog;
  final CatalogPreferences preferences;

  @override
  State<ProductSuggestions> createState() => _ProductSuggestionsState();
}

class _ProductSuggestionsState extends State<ProductSuggestions> {
  late ProductSearchController _search;
  String? _lastText;
  var _enabled = true;

  @override
  void initState() {
    super.initState();
    _search = ProductSearchController(widget.catalog);
    widget.description.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(covariant ProductSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description != widget.description) {
      oldWidget.description.removeListener(_changed);
      widget.description.addListener(_changed);
      _lastText = null;
    }
    if (oldWidget.catalog != widget.catalog) {
      _search.dispose();
      _search = ProductSearchController(widget.catalog);
      _lastText = null;
    }
    _changed();
  }

  void _changed() {
    final text = widget.description.text;
    if (text != _lastText) {
      _lastText = text;
      if (_enabled) {
        _search.search(text);
      }
    }
  }

  void _toggle() {
    setState(() => _enabled = !_enabled);
    _search.search(_enabled ? widget.description.text : '');
  }

  Future<void> _review(CatalogProduct product) async {
    final selection = await Navigator.of(context).push<ProductSelection>(
      MaterialPageRoute(
        builder: (_) => ProductStoreScreen(
          product: product,
          catalog: widget.catalog,
          preferences: widget.preferences,
        ),
      ),
    );
    if (mounted && selection != null) {
      if (widget.description.text.trim().isEmpty) {
        widget.description.text = selection.fillEmptyDescription('');
      }
      widget.purpose.text = selection.appendToPurpose(widget.purpose.text);
    }
  }

  @override
  void dispose() {
    widget.description.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _search,
    builder: (context, _) => Surface(
      child: HMBFormSection(
        children: [
          Text(
            'Product suggestions · demo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Fictional products and sample AUD prices. '
            'Review a suggestion to add it. '
            'Your quantity and pricing stay unchanged.',
          ),
          HMBButtonSecondary(
            label: _enabled ? 'Hide suggestions' : 'Show suggestions',
            onPressed: _toggle,
            hint: 'Control background product suggestions',
          ),
          if (_enabled) ...[
            if (_search.busy)
              Semantics(
                liveRegion: true,
                child: const Text('Finding sample suggestions… Keep typing.'),
              ),
            if (_search.error != null) ...[
              Text(_search.error!),
              HMBButtonSecondary(
                label: 'Retry suggestions',
                onPressed: () =>
                    _search.search(widget.description.text, immediate: true),
                hint: 'Try suggestions again',
              ),
            ],
            if (!_search.busy &&
                _search.error == null &&
                _search.results.isEmpty)
              Text(
                _search.query.length < 2
                    ? 'Describe the item to see suggestions.'
                    : 'No sample suggestions. Keep your description '
                          'or try product search.',
              ),
            for (final product in _search.results.take(3))
              HMBFormSection(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 64,
                        child: ProductPicture(product: product),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HMBFormSection(
                          children: [
                            Text(product.name),
                            Text(product.priceLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                  HMBButtonSecondary(
                    label: 'Review ${product.id}',
                    onPressed: () => unawaited(_review(product)),
                    hint: 'Review ${product.name} and choose a store',
                  ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}
