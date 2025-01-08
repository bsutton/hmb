import 'package:flutter/material.dart';

import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';
import 'source.dart';

class CustomerSource extends Source<Customer> {
  CustomerSource() : super(name: 'customer');

  Customer? customer;

  @override
  Widget widget(MessageData data) => HMBDroplist<Customer>(
        title: 'Customer',
        selectedItem: () async => customer,
        items: (filter) async => DaoCustomer().getByFilter(filter),
        format: (customer) => customer.name,
        onChanged: (customer) {
          this.customer = customer;
          // Reset site and contact when customer changes
          onChanged?.call(customer, ResetFields(site: true, contact: true));
        },
      );

  @override
  Customer? get value => customer;

// /// Customer placeholder drop list
// PlaceHolderField<Customer> _buildCustomerDroplist(
//     CustomerName placeholder, MessageData data) {
//   placeholder.setValue(data.customer);

//   final widget = HMBDroplist<Customer>(
//     title: 'Customer',
//     selectedItem: () async => placeholder.customer,
//     items: (filter) async => DaoCustomer().getByFilter(filter),
//     format: (customer) => customer.name,
//     onChanged: (customer) {
//       placeholder.customer = customer;
//       // Reset site and contact when customer changes
//       placeholder.onChanged
//           ?.call(customer, ResetFields(site: true, contact: true));
//     },
//   );
//   return PlaceHolderField(
//       placeholder: placeholder,
//       widget: widget,
//       getValue: (data) async => placeholder.value(data));
// }
}
