import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../crud/customer/edit_customer_screen.dart';
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
  Future<Customer?> _getInitialCustomer() async =>
      DaoCustomer().getById(widget.selectedCustomer.customerId);

  Future<List<Customer>> _getCustomers(String? filter) async =>
      DaoCustomer().getByFilter(filter);

  void _onCustomerChanged(Customer? newValue) {
    setState(() {
      widget.selectedCustomer.customerId = newValue?.id;
    });
    widget.onSelected?.call(newValue);
  }

  Future<void> _addCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute<Customer>(
          builder: (context) => const CustomerEditScreen()),
    );
    if (customer != null) {
      setState(() {
        widget.selectedCustomer.customerId = customer.id;
      });
      widget.onSelected?.call(customer);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: HMBDroplist<Customer>(
              title: 'Customer',
              initialItem: _getInitialCustomer,
              onChanged: _onCustomerChanged,
              items: (filter) async => _getCustomers(filter),
              format: (customer) => customer.name,
            ),
          ),
          Center(
            child: HMBButtonAdd(
              enabled: true,
              onPressed: _addCustomer,
            ),
          ),
        ],
      );
}

class SelectedCustomer extends JuneState {
  SelectedCustomer();

  int? customerId;
}
