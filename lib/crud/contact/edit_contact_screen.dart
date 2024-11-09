import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../dao/dao_contact.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/contact.dart';
import '../../entity/customer.dart';
import '../../entity/entity.dart';
import '../../util/platform_ex.dart';
import '../../widgets/fields/hmb_email_field.dart';
import '../../widgets/fields/hmb_name_field.dart';
import '../../widgets/fields/hmb_phone_field.dart';
import '../base_nested/edit_nested_screen.dart';

class ContactEditScreen<P extends Entity<P>> extends StatefulWidget {
  const ContactEditScreen(
      {required this.parent, required this.daoJoin, super.key, this.contact});
  final DaoJoinAdaptor daoJoin;
  final P parent;
  final Contact? contact;

  @override
  // ignore: library_private_types_in_public_api
  _ContactEditScreenState createState() => _ContactEditScreenState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Contact?>('contact', contact));
  }
}

class _ContactEditScreenState extends State<ContactEditScreen>
    implements NestedEntityState<Contact> {
  late TextEditingController _firstNameController;
  late TextEditingController _surnameController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _landlineController;
  late TextEditingController _officeNumberController;
  late TextEditingController _emailaddressController;
  late FocusNode _firstNameFocusNode;

  @override
  Contact? currentEntity;

  @override
  void initState() {
    super.initState();
    currentEntity ??= widget.contact;
    _firstNameController =
        TextEditingController(text: currentEntity?.firstName);
    _surnameController = TextEditingController(text: currentEntity?.surname);
    _mobileNumberController =
        TextEditingController(text: currentEntity?.mobileNumber);
    _landlineController = TextEditingController(text: currentEntity?.landLine);
    _officeNumberController =
        TextEditingController(text: currentEntity?.officeNumber);
    _emailaddressController =
        TextEditingController(text: currentEntity?.emailAddress);

    _firstNameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _mobileNumberController.dispose();
    _landlineController.dispose();
    _officeNumberController.dispose();
    _emailaddressController.dispose();
    _firstNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NestedEntityEditScreen<Contact, Customer>(
        entityName: 'Contact',
        dao: DaoContact(),
        onInsert: (contact) async =>
            widget.daoJoin.insertForParent(contact!, widget.parent),
        entityState: this,
        editor: (contact) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HMBNameField(
              controller: _firstNameController,
              focusNode: _firstNameFocusNode,
              autofocus: isNotMobile,
              labelText: 'First Name',
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the first name';
                }
                return null;
              },
            ),
            HMBNameField(
              controller: _surnameController,
              labelText: 'Surname',
              keyboardType: TextInputType.name,
            ),
            HMBPhoneField(
              controller: _mobileNumberController,
              labelText: 'Mobile Number',
            ),
            HMBPhoneField(
                controller: _landlineController, labelText: 'Landline'),
            HMBPhoneField(
                controller: _officeNumberController,
                labelText: 'Office Number'),
            HMBEmailField(
              controller: _emailaddressController,
              labelText: 'Email',
            ),
          ],
        ),
      );

  @override
  Future<Contact> forUpdate(Contact contact) async => Contact.forUpdate(
        entity: contact,
        firstName: _firstNameController.text,
        surname: _surnameController.text,
        mobileNumber: _mobileNumberController.text,
        landLine: _landlineController.text,
        officeNumber: _officeNumberController.text,
        emailAddress: _emailaddressController.text,
      );

  @override
  Future<Contact> forInsert() async => Contact.forInsert(
        firstName: _firstNameController.text,
        surname: _surnameController.text,
        mobileNumber: _mobileNumberController.text,
        landLine: _landlineController.text,
        officeNumber: _officeNumberController.text,
        emailAddress: _emailaddressController.text,
      );
  @override
  void refresh() {
    setState(() {});
  }
}
