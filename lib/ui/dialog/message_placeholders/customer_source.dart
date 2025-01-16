import 'package:flutter/material.dart';

import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../source_context.dart';
import 'source.dart';

class CustomerSource extends Source<Customer> {
  CustomerSource() : super(name: 'customer');

  final customerNotifier = ValueNotifier<Customer?>(null);

  Customer? customer;

  @override
  Widget widget() => ValueListenableBuilder(
      valueListenable: customerNotifier,
      builder: (context, customer, _) => HMBDroplist<Customer>(
            title: 'Customer',
            selectedItem: () async => customer,
            items: (filter) async => DaoCustomer().getByFilter(filter),
            format: (customer) => customer.name,
            onChanged: (customer) {
              this.customer = customer;
              customerNotifier.value = customer;
              // Reset site and contact when customer changes
              onChanged.call(customer, ResetFields(site: true, contact: true));
            },
          ));

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
