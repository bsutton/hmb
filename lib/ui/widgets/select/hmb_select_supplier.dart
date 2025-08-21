/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_supplier.dart';
import '../../../entity/supplier.dart';
import '../../crud/supplier/edit_supplier_screen.dart';
import 'hmb_droplist.dart';

class HMBSelectSupplier extends StatefulWidget {
  const HMBSelectSupplier({
    required this.selectedSupplier,
    super.key,
    this.onSelected,
    this.isRequired = false, // New parameter with default value
  });

  final SelectedSupplier selectedSupplier;
  final void Function(Supplier? supplier)? onSelected;
  final bool isRequired; // New field to indicate if the selection is required

  @override
  HMBSelectSupplierState createState() => HMBSelectSupplierState();
}

class HMBSelectSupplierState extends State<HMBSelectSupplier> {
  Future<Supplier?> _getInitialSupplier() =>
      DaoSupplier().getById(widget.selectedSupplier.selected);

  Future<List<Supplier>> _getSuppliers(String? filter) =>
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
        builder: (context) => const SupplierEditScreen(),
      ),
    );
    if (supplier != null) {
      setState(() {
        widget.selectedSupplier.selected = supplier.id;
      });
      widget.onSelected?.call(supplier);
    }
  }

  @override
  Widget build(BuildContext context) => JuneBuilder(
    () => widget.selectedSupplier,
    id: widget.selectedSupplier,
    builder: (context) {
      // print(
      //   'build called: hash: ${widget.selectedSupplier.hashCode} value:
      // ${widget.selectedSupplier._selected}',
      // );
      final hmbDroplist = HMBDroplist<Supplier>(
        key: ValueKey(widget.selectedSupplier._selected),
        title: widget.isRequired ? 'Supplier *' : 'Supplier',
        selectedItem: _getInitialSupplier,
        onChanged: _onSupplierChanged,
        onAdd: _addSupplier,
        items: _getSuppliers,
        format: (supplier) => supplier.name,
        required: widget.isRequired,
      );
      return hmbDroplist;
    },
  );

  // void clear() {
  //   _droplistKey.currentState?.clear();
  //   June.getState(() => widget.selectedSupplier).selected = null;
  // }
}

class SelectedSupplier extends JuneState {
  // SelectedSupplier() {
  //   print('created selected supplier: $hashCode');
  // }
  int? _selected;

  set selected(int? value) {
    _selected = value;
    setState([this]);
    // print('setting state to $value for hash $hashCode');
  }

  int? get selected => _selected;
}
