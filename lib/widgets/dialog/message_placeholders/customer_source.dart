import 'package:flutter/material.dart';

import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'source.dart';

class CustomerSource extends Source<Customer> {
  CustomerSource() : super(name: 'customer');

  @override
  Widget field(MessageData data) {
    return HMBDroplist<Customer>(
      title: 'Customer',
      selectedItem: () async => value,
      items: (filter) async => DaoCustomer().getByFilter(filter),
      format: (customer) => customer.name,
      onChanged: (customer) {
        setValue(customer);
      },
    );
  }
}
