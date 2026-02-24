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

import '../../../entity/customer.dart';
import 'contact_source.dart';
import 'customer_source.dart';
import 'place_holder.dart';

class CustomerName extends PlaceHolder<Customer> {
  // ignore: omit_obvious_property_types
  static String tagName = 'customer.name';
  static const _tagBase = 'customer';

  final CustomerSource customerSource;
  final ContactSource? contactSource;

  CustomerName({required this.customerSource, this.contactSource})
    : super(name: tagName, base: _tagBase, source: customerSource);

  @override
  Future<String> value() async {
    final contactName = contactSource?.value?.firstName.trim() ?? '';
    if (contactName.isNotEmpty) {
      return contactName;
    }
    return customerSource.value?.name ?? '';
  }
}
