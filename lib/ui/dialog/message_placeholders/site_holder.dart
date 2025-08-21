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

import '../../../entity/site.dart';
import 'place_holder.dart';
import 'site_source.dart';

class SiteHolder extends PlaceHolder<Site> {
  // ignore: omit_obvious_property_types
  static String tagName = 'site.address';
  static const _tagBase = 'site';

  final SiteSource siteSource;

  SiteHolder({required this.siteSource})
    : super(name: tagName, base: _tagBase, source: siteSource);

  @override
  Future<String> value() async => siteSource.value?.address ?? '';
}
