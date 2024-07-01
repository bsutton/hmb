import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../crud/contact/contact_edit_screen.dart';
import '../dao/dao_contact.dart';
import '../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../entity/contact.dart';
import '../entity/customer.dart';
import 'hmb_add_button.dart';
import 'hmb_droplist.dart';

/// Allows the user to select a Primary Contact from the contacts
/// owned by a customer and and the associate them with another
/// entity e.g. a job.
class HMBSelectContact extends StatefulWidget {
  const HMBSelectContact(
      {required this.initialContact, required this.customer, super.key});

  /// The customer that owns the contact.
  final Customer? customer;
  final SelectedContact initialContact;

  @override
  HMBSelectContactState createState() => HMBSelectContactState();
}

class HMBSelectContactState extends State<HMBSelectContact> {
  @override
  Widget build(BuildContext context) {
    if (widget.customer == null) {
      return const Center(child: Text('Contacts: Select a customer first.'));
    } else {
      return Row(
        children: [
          Expanded(
            child: HMBDroplist<Contact>(
                title: 'Contact',
                initialItem: () async =>
                    DaoContact().getById(widget.initialContact.contactId),
                onChanged: (newValue) {
                  setState(() {
                    widget.initialContact.contactId = newValue.id;
                  });
                },
                items: (filter) async =>
                    DaoContact().getByCustomer(widget.customer?.id),
                format: (contact) => ' ${contact.firstName} ${contact.surname}',
                required: false),
          ),
          HMBButtonAdd(
              enabled: true,
              onPressed: () async {
                final customer = await Navigator.push<Contact>(
                  context,
                  MaterialPageRoute<Contact>(
                      builder: (context) => ContactEditScreen<Customer>(
                          parent: widget.customer!,
                          daoJoin: JoinAdaptorCustomerContact())),
                );
                setState(() {
                  widget.initialContact.contactId = customer?.id;
                });
              }),
        ],
      );
    }
  }
}

class SelectedContact extends JuneState {
  SelectedContact();

  int? contactId;
}
