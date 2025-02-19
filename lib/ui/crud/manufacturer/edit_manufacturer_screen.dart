import 'package:flutter/material.dart';

import '../../../dao/dao_manufacturer.dart';
import '../../../entity/manufacturer.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../base_full_screen/edit_entity_screen.dart';

class ManufacturerEditScreen extends StatefulWidget {
  const ManufacturerEditScreen({super.key, this.manufacturer});
  final Manufacturer? manufacturer;

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
    editor:
        (manufacturer, {required isNew}) => Column(
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
      Manufacturer.forUpdate(
        entity: manufacturer,
        name: _nameController.text,
        description: _descriptionController.text,
      );

  @override
  Future<Manufacturer> forInsert() async => Manufacturer.forInsert(
    name: _nameController.text,
    description: _descriptionController.text,
  );

  @override
  void refresh() {
    setState(() {});
  }
}
