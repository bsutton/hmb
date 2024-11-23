import 'package:flutter/material.dart';

import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';
import 'source.dart';

class CustomerSource extends Source<Customer> {
  CustomerSource() : super(name: 'customer');

  Customer? customer;

  @override
  Widget field(MessageData data) => HMBDroplist<Customer>(
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
}


// => HMBDroplist<Customer>(
//         title: 'Customer',
//         selectedItem: () async => value,
//         items: (filter) async => DaoCustomer().getByFilter(filter),
//         format: (customer) => customer.name,
//         onChanged: setValue,
//       );
