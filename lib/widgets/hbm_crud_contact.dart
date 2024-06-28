import 'package:flutter/material.dart';

import '../../entity/contact.dart';
import '../../entity/entity.dart';
import '../../widgets/hmb_child_crud_card.dart';
import '../crud/base_nested/nested_list_screen.dart';
import '../crud/contact/contact_list_screen.dart';
import '../dao/join_adaptors/dao_join_adaptor.dart';

class HMBCrudContact<P extends Entity<P>> extends StatefulWidget {
  const HMBCrudContact({
    required this.parent,
    required this.daoJoin,
    required this.parentTitle,
    super.key,
  });

  final DaoJoinAdaptor<Contact, P> daoJoin;
  final Parent<P> parent;
  final String parentTitle;

  @override
  // ignore: library_private_types_in_public_api
  _HMBCrudContactState<P> createState() => _HMBCrudContactState<P>();
}

class _HMBCrudContactState<P extends Entity<P>>
    extends State<HMBCrudContact<P>> {
  @override
  Widget build(BuildContext context) => widget.parent.parent == null
      ? const Center(child: Text('Save the parent first'))
      : HMBChildCrudCard(
          headline: 'Contacts',
          crudListScreen: ContactListScreen(
              daoJoin: widget.daoJoin,
              parent: widget.parent,
              parentTitle: widget.parentTitle),
        );

  @override
  void didUpdateWidget(covariant HMBCrudContact<P> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parent.parent != widget.parent.parent) {
      setState(() {});
    }
  }
}
