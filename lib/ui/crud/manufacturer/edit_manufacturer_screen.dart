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

import '../../../dao/dao_manufacturer.dart';
import '../../../entity/manufacturer.dart';
import '../../dialog/duplicate_name_warning_dialog.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../base_full_screen/edit_entity_screen.dart';

class ManufacturerEditScreen extends StatefulWidget {
  final Manufacturer? manufacturer;

  const ManufacturerEditScreen({super.key, this.manufacturer});

  @override
  ManufacturerEditScreenState createState() => ManufacturerEditScreenState();
}

class ManufacturerEditScreenState extends State<ManufacturerEditScreen>
    implements EntityState<Manufacturer> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _contactNumberController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  @override
  Manufacturer? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.manufacturer;
    _nameController = TextEditingController(text: widget.manufacturer?.name);
    _descriptionController = TextEditingController(
      text: widget.manufacturer?.description,
    );
    _contactNumberController = TextEditingController(
      text: widget.manufacturer?.contactNumber,
    );
    _emailController = TextEditingController(text: widget.manufacturer?.email);
    _addressController = TextEditingController(
      text: widget.manufacturer?.address,
    );
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<Manufacturer>(
    entityName: 'Manufacturer',
    dao: DaoManufacturer(),
    entityState: this,
    crossValidator: _validateDuplicateName,
    editor: (manufacturer, {required isNew}) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HMBTextField(
          controller: _nameController,
          labelText: 'Name',
          required: true,
        ),
        HMBTextField(
          controller: _descriptionController,
          labelText: 'Description',
        ),
        HMBTextField(
          controller: _contactNumberController,
          labelText: 'Contact Number',
          keyboardType: TextInputType.phone,
        ),
        HMBTextField(
          controller: _emailController,
          labelText: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        HMBTextField(controller: _addressController, labelText: 'Address'),
      ],
    ),
  );

  @override
  Future<Manufacturer> forUpdate(Manufacturer manufacturer) async =>
      manufacturer.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
      );

  @override
  Future<Manufacturer> forInsert() async => Manufacturer.forInsert(
    name: _nameController.text,
    description: _descriptionController.text,
  );

  @override
  Future<void> postSave(_) async {
    setState(() {});
  }

  Future<bool> _validateDuplicateName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return true;
    }

    final matches = await DaoManufacturer().getByFilter(name);
    final duplicate = matches.any(
      (manufacturer) =>
          manufacturer.id != currentEntity?.id &&
          manufacturer.name.trim().toLowerCase() == name.toLowerCase(),
    );

    if (!duplicate || !mounted) {
      return true;
    }

    return showDuplicateNameWarningDialog(
      context: context,
      entityName: 'manufacturer',
      name: name,
    );
  }
}
