/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao_supplier.dart';
import '../../../dao/join_adaptors/join_adaptor_supplier_contact.dart';
import '../../../dao/join_adaptors/join_adaptor_supplier_site.dart';
import '../../../entity/supplier.dart';
import '../../../util/platform_ex.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hbm_crud_contact.dart';
import '../../widgets/hmb_crud_site.dart';
import '../../widgets/layout/hmb_form_section.dart';
import '../base_full_screen/edit_entity_screen.dart';
import '../base_nested/list_nested_screen.dart';

class SupplierEditScreen extends StatefulWidget {
  const SupplierEditScreen({super.key, this.supplier});
  final Supplier? supplier;

  @override
  SupplierEditScreenState createState() => SupplierEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Supplier?>('supplier', supplier));
  }
}

class SupplierEditScreenState extends State<SupplierEditScreen>
    implements EntityState<Supplier> {
  late TextEditingController _nameController;
  late TextEditingController _businessNumberController;
  late TextEditingController _descriptionController;
  late TextEditingController _bsbController;
  late TextEditingController _accountNumberController;
  late TextEditingController _serviceController;

  @override
  Supplier? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.supplier;
    _nameController = TextEditingController(text: widget.supplier?.name);
    _businessNumberController = TextEditingController(
      text: widget.supplier?.businessNumber,
    );
    _descriptionController = TextEditingController(
      text: widget.supplier?.description,
    );
    _bsbController = TextEditingController(text: widget.supplier?.bsb);
    _accountNumberController = TextEditingController(
      text: widget.supplier?.accountNumber,
    );
    _serviceController = TextEditingController(text: widget.supplier?.service);
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<Supplier>(
    entityName: 'Supplier',
    dao: DaoSupplier(),
    entityState: this,
    editor: (supplier, {required isNew}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HMBFormSection(
              children: [
                Text(
                  'Supplier Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                HMBTextField(
                  autofocus: isNotMobile,
                  controller: _nameController,
                  labelText: 'Name',
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  required: true,
                ),
                HMBTextField(
                  controller: _serviceController,
                  labelText: 'Service',
                ),
                HMBTextArea(
                  controller: _descriptionController,
                  labelText: 'Description',
                ),
                HMBTextField(
                  controller: _businessNumberController,
                  labelText: 'Business Number',
                ),
                HMBTextField(
                  controller: _bsbController,
                  labelText: 'BSB',
                  keyboardType: TextInputType.number,
                ),
                HMBTextField(
                  controller: _accountNumberController,
                  labelText: 'Account Number',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            HMBCrudContact(
              parentTitle: 'Supplier',
              parent: Parent(supplier),
              daoJoin: JoinAdaptorSupplierContact(),
            ),
            HBMCrudSite(
              parentTitle: 'Supplier',
              daoJoin: JoinAdaptorSupplierSite(),
              parent: Parent(supplier),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Future<Supplier> forUpdate(Supplier supplier) async => Supplier.forUpdate(
    entity: supplier,
    name: _nameController.text,
    businessNumber: _businessNumberController.text,
    description: _descriptionController.text,
    bsb: _bsbController.text,
    accountNumber: _accountNumberController.text,
    service: _serviceController.text,
  );

  @override
  Future<Supplier> forInsert() async => Supplier.forInsert(
    name: _nameController.text,
    businessNumber: _businessNumberController.text,
    description: _descriptionController.text,
    bsb: _bsbController.text,
    accountNumber: _accountNumberController.text,
    service: _serviceController.text,
  );

  @override
  Future<void> postSave(_) async {
    setState(() {});
  }
}
