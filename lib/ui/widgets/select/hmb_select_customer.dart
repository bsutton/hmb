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

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../../ui/widgets/hmb_add_button.dart';
import '../../crud/customer/edit_customer_screen.dart';
import 'hmb_droplist.dart';

class HMBSelectCustomer extends StatefulWidget {
  const HMBSelectCustomer({
    required this.selectedCustomer,
    super.key,
    this.onSelected,
    this.required = false,
  });
  final SelectedCustomer selectedCustomer;
  final void Function(Customer? customer)? onSelected;
  final bool required;

  @override
  HMBSelectCustomerState createState() => HMBSelectCustomerState();
}

class HMBSelectCustomerState extends State<HMBSelectCustomer> {
  Future<Customer?> _getInitialCustomer() =>
      DaoCustomer().getById(widget.selectedCustomer.customerId);

  Future<List<Customer>> _getCustomers(String? filter) =>
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
        builder: (context) => const CustomerEditScreen(),
      ),
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
          selectedItem: _getInitialCustomer,
          onChanged: _onCustomerChanged,
          items: _getCustomers,
          format: (customer) => customer.name,
          onAdd: _addCustomer,
          required: widget.required,
        ),
      ),
      Center(child: HMBButtonAdd(enabled: true, onAdd: _addCustomer)),
    ],
  );
}

class SelectedCustomer extends JuneState {
  SelectedCustomer();

  int? _customerId;

  int? get customerId => _customerId;

  set customerId(int? arg) {
    _customerId = arg;
    setState();
  }
}
