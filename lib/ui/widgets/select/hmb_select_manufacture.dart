/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_manufacturer.dart';
import '../../../entity/manufacturer.dart';
import '../../../ui/widgets/hmb_add_button.dart';
import '../../crud/manufacturer/edit_manufacturer_screen.dart';
import 'hmb_droplist.dart';

class HMBSelectManufacturer extends StatefulWidget {
  const HMBSelectManufacturer({
    required this.selectedManufacturer,
    super.key,
    this.onSelected,
    this.isRequired = false, // New parameter with default value
  });

  final SelectedManufacturer selectedManufacturer;
  final void Function(Manufacturer? manufacturer)? onSelected;
  final bool isRequired; // New field to indicate if the selection is required

  @override
  HMBSelectManufacturerState createState() => HMBSelectManufacturerState();
}

class HMBSelectManufacturerState extends State<HMBSelectManufacturer> {
  Future<Manufacturer?> _getInitialManufacturer() =>
      DaoManufacturer().getById(widget.selectedManufacturer.manufacturerId);

  Future<List<Manufacturer>> _getManufacturers(String? filter) =>
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
        builder: (context) => const ManufacturerEditScreen(),
      ),
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
          items: _getManufacturers,
          format: (manufacturer) => manufacturer.name,
          required: widget.isRequired,
        ),
      ),
      Center(child: HMBButtonAdd(enabled: true, onPressed: _addManufacturer)),
    ],
  );
}

class SelectedManufacturer extends JuneState {
  SelectedManufacturer();

  int? manufacturerId;
}
