import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../api/product_catalog/catalog_preferences.dart';
import '../../api/product_catalog/demo_product_catalog.dart';
import '../../api/product_catalog/product_catalog.dart';
import '../widgets/hmb_button.dart';
import 'product_search_screen.dart';

/// Writes only after an explicit selection and against the current form text.
class TaskProductPicker extends StatelessWidget {
  const TaskProductPicker({
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

  Future<void> _open(BuildContext context) async {
    final selection = await Navigator.of(context).push<ProductSelection>(
      MaterialPageRoute(
        builder: (_) => ProductSearchScreen(
          initialQuery: description.text,
          catalog: catalog,
          preferences: preferences,
        ),
      ),
    );
    if (context.mounted && selection != null) {
      description.text = selection.fillEmptyDescription(description.text);
      purpose.text = selection.appendToPurpose(purpose.text);
    }
  }

  @override
  Widget build(BuildContext context) => HMBButtonSecondary(
    label: 'Find a product (demo)',
    hint: 'Browse the Bunnings concept with fictional data',
    onPressed: () => unawaited(_open(context)),
  );
}
