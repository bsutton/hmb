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


import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../entity/site.dart';

class GoogleMaps {
  GoogleMaps._();

  static Future<void> openMap(BuildContext context, Site site) async {
    /// https://github.com/flutter/flutter/issues/159014
    // if (await canLaunchUrl(Uri.parse(site.toGoogleMapsQuery()))) {
    await launchUrl(Uri.parse(site.toGoogleMapsQuery()));
    // }

    // else {
    //   if (context.mounted) {
    //     HMBToast.error( 'Could not open the map.');
    //   }
    // }
  }
}
