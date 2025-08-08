/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/join_adaptors/dao_join_adaptor.dart';
import '../../../entity/contact.dart';
import '../../../entity/entity.dart';
import '../../dialog/source_context.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../base_nested/list_nested_screen.dart';
import 'edit_contact_screen.dart';

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
    // ignore: discarded_futures
    onDelete: (contact) => daoJoin.deleteFromParent(contact, parent.parent!),
    details: (entity, details) {
      final contact = entity;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HMBPhoneText(
            label: '',
            phoneNo: contact.bestPhone,
            sourceContext: SourceContext(contact: contact),
          ),
          HMBEmailText(label: '', email: contact.emailAddress),
        ],
      );
    },
  );
}
