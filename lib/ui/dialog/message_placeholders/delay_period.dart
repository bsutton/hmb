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

import 'delay_source.dart';
import 'place_holder.dart';

class DelayPeriod extends PlaceHolder<String> {
  DelayPeriod({required this.delaySource})
    : super(name: tagName, base: _tagBase, source: delaySource);

  // ignore: omit_obvious_property_types
  static String tagName = 'delay_period';
  static const _tagBase = 'delay_period';

  final DelaySource delaySource;

  @override
  Future<String> value() async => delaySource.delay;
}
