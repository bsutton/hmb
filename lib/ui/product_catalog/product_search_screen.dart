import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/product_catalog/catalog_preferences.dart';
import '../../api/product_catalog/demo_product_catalog.dart';
import '../../api/product_catalog/product_catalog.dart';
import '../../api/product_catalog/product_search_controller.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/hmb_form_section.dart';
import '../widgets/layout/hmb_full_page_child_screen.dart';
import 'product_card.dart';
import 'product_store_screen.dart';

const catalogDemoNotice =
    'Bunnings concept · DEMO ONLY. Fictional products, '
    'illustrations, prices and stores. No live stock or Bunnings connection.';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({
    super.key,
    this.initialQuery = '',
    this.catalog = const DemoProductCatalog(),
    this.preferences = const SavedCatalogPreferences(),
  });

  final String initialQuery;
  final ProductCatalog catalog;
  final CatalogPreferences preferences;

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late final _search = ProductSearchController(widget.catalog);

  @override
  void initState() {
    super.initState();
    // Schedules a user-query search, not asynchronous widget initialization.
    _search.search(widget.initialQuery);
  }

  @override
  void dispose() {
    _query.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _details(CatalogProduct product) async {
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
      Navigator.of(context).pop(selection);
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Product search demo',
    maxContentWidth: 900,
    child: ListenableBuilder(
      listenable: _search,
      builder: (context, _) => HMBFormList(
        children: [
          const Text(catalogDemoNotice),
          HMBTextField(
            controller: _query,
            labelText: 'Search sample products',
            onChanged: (text) => _search.search(text ?? ''),
          ),
          const Text('Try paint, timber, screws, sealant or plasterboard.'),
          if (_search.busy)
            Semantics(
              liveRegion: true,
              child: const Text(
                'Searching sample products… You can keep typing.',
              ),
            ),
          if (_search.error != null) ...[
            Text(_search.error!),
            HMBButtonSecondary(
              label: 'Retry search',
              onPressed: () => _search.search(_query.text, immediate: true),
              hint: 'Try the product search again',
            ),
          ],
          if (!_search.busy && _search.error == null && _search.results.isEmpty)
            Text(
              _search.query.length < 2
                  ? 'Type at least two characters.'
                  : 'No sample products match. Try another description.',
            ),
          for (final product in _search.results)
            ProductCard(
              product: product,
              onDetails: () => unawaited(_details(product)),
            ),
        ],
      ),
    ),
  );
}
