import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../crud/manufacturer/edit_manufacturer_screen.dart';
import '../../dao/dao_manufacturer.dart';
import '../../entity/manufacturer.dart';
import '../hmb_add_button.dart';
import 'hmb_droplist.dart';

class SelectManufacturer extends StatefulWidget {
  const SelectManufacturer({
    required this.selectedManufacturer,
    super.key,
    this.onSelected,
    this.isRequired = false, // New parameter with default value
  });

  final SelectedManufacturer selectedManufacturer;
  final void Function(Manufacturer? manufacturer)? onSelected;
  final bool isRequired; // New field to indicate if the selection is required

  @override
  SelectManufacturerState createState() => SelectManufacturerState();
}

class SelectManufacturerState extends State<SelectManufacturer> {
  Future<Manufacturer?> _getInitialManufacturer() async =>
      DaoManufacturer().getById(widget.selectedManufacturer.manufacturerId);

  Future<List<Manufacturer>> _getManufacturers(String? filter) async =>
      DaoManufacturer().getByFilter(filter);

  void _onManufacturerChanged(Manufacturer? newValue) {
    setState(() {
      widget.selectedManufacturer.manufacturerId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  Future<void> _addManufacturer() async {
    final manufacturer = await Navigator.push<Manufacturer>(
      context,
      MaterialPageRoute<Manufacturer>(
          builder: (context) => const ManufacturerEditScreen()),
    );
    if (manufacturer != null) {
      setState(() {
        widget.selectedManufacturer.manufacturerId = manufacturer.id;
      });
      widget.onSelected?.call(manufacturer);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: HMBDroplist<Manufacturer>(
              title: widget.isRequired ? 'Manufacturer *' : 'Manufacturer',
              selectedItem: _getInitialManufacturer,
              onChanged: _onManufacturerChanged,
              items: (filter) async => _getManufacturers(filter),
              format: (manufacturer) => manufacturer.name,
              required: widget.isRequired,
            ),
          ),
          Center(
            child: HMBButtonAdd(
              enabled: true,
              onPressed: _addManufacturer,
            ),
          ),
        ],
      );
}

class SelectedManufacturer extends JuneState {
  SelectedManufacturer();

  int? manufacturerId;
}