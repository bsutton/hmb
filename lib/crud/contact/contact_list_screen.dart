import 'package:flutter/material.dart';

import '../../dao/dao_contact.dart';
import '../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../entity/contact.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_email_text.dart';
import '../../widgets/hmb_phone_text.dart';
import '../base_nested/nested_list_screen.dart';
import 'contact_edit_screen.dart';

class ContactListScreen<P extends Entity<P>> extends StatelessWidget {
  const ContactListScreen({
    required this.parent,
    required this.daoJoin,
    required this.parentTitle,
    super.key,
  });

  final Parent<P> parent;
  final DaoJoinAdaptor<Contact, P> daoJoin;
  final String parentTitle;

  @override
  Widget build(BuildContext context) => NestedEntityListScreen<Contact, P>(
      parent: parent,
      parentTitle: parentTitle,
      entityNamePlural: 'Contacts',
      entityNameSingular: 'Contact',
      dao: DaoContact(),
      // ignore: discarded_futures
      fetchList: () => daoJoin.getByParent(parent.parent),
      title: (entity) => Text('${entity.firstName} ${entity.surname}'),
      onEdit: (contact) => ContactEditScreen(
            parent: parent.parent!,
            contact: contact,
            daoJoin: daoJoin,
          ),
      onDelete: (contact) async =>
          daoJoin.deleteFromParent(contact!, parent.parent!),
      onInsert: (contact) async =>
          daoJoin.insertForParent(contact!, parent.parent!),
      details: (entity, details) {
        final customer = entity;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HMBPhoneText(label: '', phoneNo: customer.mobileNumber),
          HMBEmailText(label: '', email: customer.emailAddress)
        ]);
      });
}
