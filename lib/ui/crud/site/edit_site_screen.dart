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

// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao_site.dart';
import '../../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../../entity/customer.dart';
import '../../../entity/entity.dart';
import '../../../entity/site.dart';
import '../../../util/dart/parse/parse_customer.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../base_nested/edit_nested_screen.dart';
import '../customer/customer_paste_panel.dart';

class SiteEditScreen<P extends Entity<P>> extends StatefulWidget {
  final P parent;
  final Site? site;
  final DaoJoinAdaptor<Site, P> daoJoin;

  const SiteEditScreen({
    required this.parent,
    required this.daoJoin,
    super.key,
    this.site,
  });

  @override
  _SiteEditScreenState createState() => _SiteEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Site?>('Site', site));
  }
}

class _SiteEditScreenState extends State<SiteEditScreen>
    implements NestedEntityState<Site> {
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _suburbController;
  late TextEditingController _stateController;
  late TextEditingController _postcodeController;
  late TextEditingController _accessDetailsController;

  @override
  Site? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.site;
    _addressLine1Controller = TextEditingController(
      text: currentEntity?.addressLine1,
    );
    _addressLine2Controller = TextEditingController(
      text: currentEntity?.addressLine2,
    );
    _suburbController = TextEditingController(text: currentEntity?.suburb);
    _stateController = TextEditingController(text: currentEntity?.state);
    _postcodeController = TextEditingController(text: currentEntity?.postcode);
    _accessDetailsController = TextEditingController(
      text: currentEntity?.accessDetails,
    ); // New field
  }

  @override
  Widget build(BuildContext context) => NestedEntityEditScreen<Site, Customer>(
    entityName: 'Site',
    dao: DaoSite(),
    entityState: this,
    onInsert:
        // ignore: discarded_futures
        (site, transaction) =>
            widget.daoJoin.insertForParent(site!, widget.parent, transaction),
    editor: (site) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (site == null) CustomerPastePanel(onExtract: _onExtract),
        // Add other form fields for the new fields
        HMBTextField(
          controller: _addressLine1Controller,
          labelText: 'Address Line 1',
          textCapitalization: TextCapitalization.words,
        ),
        HMBTextField(
          controller: _addressLine2Controller,
          labelText: 'Address Line 2',
          textCapitalization: TextCapitalization.words,
        ),
        HMBTextField(
          controller: _suburbController,
          labelText: 'Suburb',
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          onChanged: print,
        ),
        HMBTextField(
          controller: _stateController,
          labelText: 'State',
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
        ),
        HMBTextField(
          controller: _postcodeController,
          labelText: 'Postcode',
          textCapitalization: TextCapitalization.characters,
        ),
        HMBTextField(
          controller: _accessDetailsController, // New field
          labelText: 'Access Details',
        ),
      ],
    ),
  );

  void _onExtract(ParsedCustomer parsedCustomer) {
    _addressLine1Controller.text = parsedCustomer.address.street;
    _suburbController.text = parsedCustomer.address.city;
    _stateController.text = parsedCustomer.address.state;
    _postcodeController.text = parsedCustomer.address.postalCode;
    setState(() {});
  }

  @override
  Future<Site> forUpdate(Site site) async => site.copyWith(
    addressLine1: _addressLine1Controller.text,
    addressLine2: _addressLine2Controller.text,
    suburb: _suburbController.text,
    state: _stateController.text,
    postcode: _postcodeController.text,
    accessDetails: _accessDetailsController.text,
  ); // New field

  @override
  Future<Site> forInsert() async => Site.forInsert(
    addressLine1: _addressLine1Controller.text,
    addressLine2: _addressLine2Controller.text,
    suburb: _suburbController.text,
    state: _stateController.text,
    postcode: _postcodeController.text,
    accessDetails: _accessDetailsController.text, // New field
  );

  @override
  void refresh() {
    setState(() {});
  }

  @override
  Future<void> postSave(Transaction transaction, Operation operation) async {}
}
