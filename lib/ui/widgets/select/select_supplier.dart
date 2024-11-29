import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_supplier.dart';
import '../../../entity/supplier.dart';
import '../../../ui/widgets/hmb_add_button.dart';
import '../../crud/supplier/edit_supplier_screen.dart';
import 'hmb_droplist.dart';

class SelectSupplier extends StatefulWidget {
  const SelectSupplier({
    required this.selectedSupplier,
    super.key,
    this.onSelected,
    this.isRequired = false, // New parameter with default value
  });

  final SelectedSupplier selectedSupplier;
  final void Function(Supplier? supplier)? onSelected;
  final bool isRequired; // New field to indicate if the selection is required

  @override
  SelectSupplierState createState() => SelectSupplierState();
}

class SelectSupplierState extends State<SelectSupplier> {
  Future<Supplier?> _getInitialSupplier() async =>
      DaoSupplier().getById(widget.selectedSupplier.selected);

  Future<List<Supplier>> _getSuppliers(String? filter) async =>
      DaoSupplier().getByFilter(filter);

  void _onSupplierChanged(Supplier? newValue) {
    setState(() {
      widget.selectedSupplier.selected = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  Future<void> _addSupplier() async {
    final supplier = await Navigator.push<Supplier>(
      context,
      MaterialPageRoute<Supplier>(
          builder: (context) => const SupplierEditScreen()),
    );
    if (supplier != null) {
      setState(() {
        widget.selectedSupplier.selected = supplier.id;
      });
      widget.onSelected?.call(supplier);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: HMBDroplist<Supplier>(
              title: widget.isRequired ? 'Supplier *' : 'Supplier',
              selectedItem: _getInitialSupplier,
              onChanged: _onSupplierChanged,
              items: (filter) async => _getSuppliers(filter),
              format: (supplier) => supplier.name,
              required: widget.isRequired,
            ),
          ),
          Center(
            child: HMBButtonAdd(
              enabled: true,
              onPressed: _addSupplier,
            ),
          ),
        ],
      );
}

class SelectedSupplier extends JuneState {
  int? _selected;

  set selected(int? value) {
    _selected = value;
    setState();
  }

  int get selected => _selected ?? 0;
}
