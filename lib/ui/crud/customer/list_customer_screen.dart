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
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'customer_creator.dart';
import 'edit_customer_screen.dart';
import 'list_customer_card.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Customer>(
    entityNameSingular: 'Customer',
    entityNamePlural: 'Customers',

    dao: DaoCustomer(),
    listCardTitle: (entity) => HMBCardHeading(entity.name),
    // ignore: discarded_futures
    fetchList: (filter) => DaoCustomer().getByFilter(filter),
    onAdd: () => CustomerCreator.show(context),
    onEdit: (customer) => CustomerEditScreen(customer: customer),
    listCard: (entity) {
      final customer = entity;
      return ListCustomerCard(customer: customer);
    },
  );
}
