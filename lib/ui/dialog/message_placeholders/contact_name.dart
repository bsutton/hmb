/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import '../../../entity/contact.dart';
import 'contact_source.dart';
import 'place_holder.dart';

class ContactName extends PlaceHolder<Contact> {
  ContactName({required this.contactSource})
    : super(name: tagName, base: _tagbase, source: contactSource);
  final ContactSource contactSource;

  // ignore: omit_obvious_property_types
  static String tagName = 'contact.name';
  static const _tagbase = 'contact';

  @override
  Future<String> value() async => contactSource.value?.firstName ?? '';
}
