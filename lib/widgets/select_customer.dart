import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../crud/customer/customer_edit_screen.dart';
import '../dao/dao_customer.dart';
import '../entity/customer.dart';
import 'hmb_add_button.dart';
import 'hmb_droplist.dart';

class SelectCustomer extends StatefulWidget {
  const SelectCustomer(
      {required this.selectedCustomer, super.key, this.onSelected});
  final SelectedCustomer selectedCustomer;

  final void Function(Customer? customer)? onSelected;

  @override
  SelectCustomerState createState() => SelectCustomerState();
}

class SelectCustomerState extends State<SelectCustomer> {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: HMBDroplist<Customer>(
                title: 'Customer',
                initialItem: () async =>
                    DaoCustomer().getById(widget.selectedCustomer.customerId),
                // hint: const Text('Select a customer'),
                onChanged: (newValue) {
                  setState(() {
                    widget.selectedCustomer.customerId = newValue.id;
                  });
                  widget.onSelected?.call(newValue);
                },
                items: (filter) async => DaoCustomer().getByFilter(filter),
                format: (customer) => customer.name),
          ),
          Center(
            child: HMBButtonAdd(
                enabled: true,
                onPressed: () async {
                  final customer = await Navigator.push<Customer>(
                    context,
                    MaterialPageRoute<Customer>(
                        builder: (context) => const CustomerEditScreen()),
                  );
                  setState(() {
                    widget.selectedCustomer.customerId = customer?.id;
                  });
                }),
          ),
        ],
      );
}

class SelectedCustomer extends JuneState {
  SelectedCustomer();

  int? customerId;
}
