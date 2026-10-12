import 'package:fdb_helper/fdb_helper.dart';
import 'package:hmb/api/product_catalog/catalog_preferences.dart';
import 'package:hmb/ui/product_catalog/task_product_picker.dart';
import 'package:hmb/ui/widgets/blocking_ui.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/layout/hmb_form_section.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Database-free demo. Does not open HMB data or read device location.
void main() {
  FdbBinding.ensureInitialized();
  runApp(
    MaterialApp(
      theme: HMBTheme.dark,
      home: const CatalogPreview(),
      builder: (context, child) =>
          Stack(children: [child!, const BlockingOverlay()]),
    ),
  );
}

class CatalogPreview extends StatefulWidget {
  const CatalogPreview({super.key});
  @override
  State<CatalogPreview> createState() => _CatalogPreviewState();
}

class _CatalogPreviewState extends State<CatalogPreview> {
  final _description = TextEditingController(text: 'paint');
  final _purpose = TextEditingController(text: 'Repair the sample room');
  final _quantity = TextEditingController(text: '2');
  final _price = TextEditingController(text: '35.00');
  final _preferences = MemoryCatalogPreferences();

  @override
  void dispose() {
    _description.dispose();
    _purpose.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HMB · demo task item')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: HMBFormList(
          children: [
            const Text(
              'Isolated preview · fictional task · no application database',
            ),
            HMBTextField(controller: _description, labelText: 'Description'),
            TaskProductPicker(
              description: _description,
              purpose: _purpose,
              preferences: _preferences,
            ),
            HMBTextField(
              controller: _purpose,
              labelText: 'Purpose',
              maxLines: 5,
            ),
            HMBTextField(controller: _quantity, labelText: 'Quantity'),
            HMBTextField(controller: _price, labelText: 'Unit cost'),
          ],
        ),
      ),
    ),
  );
}
