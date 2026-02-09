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

import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../source_context.dart';
import 'source.dart';

class CustomerSource extends Source<Customer> {
  final customerNotifier = ValueNotifier<Customer?>(null);
  Customer? customer;

  CustomerSource() : super(name: 'customer');

  @override
  Widget widget() => ValueListenableBuilder(
    valueListenable: customerNotifier,
    builder: (context, customer, _) => HMBDroplist<Customer>(
      title: 'Customer',
      selectedItem: () async => customer,
      items: (filter) => DaoCustomer().getByFilter(filter),
      format: (customer) => customer.name,
      onChanged: (customer) {
        this.customer = customer;
        customerNotifier.value = customer;
        // Reset site and contact when customer changes
        onChanged.call(customer, ResetFields(site: true, contact: true));
      },
    ),
  );

  @override
  Customer? get value => customer;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    if (source == this) {
      return;
    }
    customerNotifier.value = sourceContext.customer;
    customer = sourceContext.customer;
  }

  @override
  void revise(SourceContext sourceContext) {
    sourceContext.customer = customer;
  }
}
