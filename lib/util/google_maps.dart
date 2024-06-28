import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../entity/site.dart';
import '../widgets/hmb_toast.dart';

class GoogleMaps {
  GoogleMaps._();

  static Future<void> openMap(BuildContext context, Site site) async {
    if (await canLaunchUrl(Uri.parse(site.toGoogleMapsQuery()))) {
      await launchUrl(Uri.parse(site.toGoogleMapsQuery()));
    } else {
      if (context.mounted) {
        HMBToast.error(context, 'Could not open the map.');
      }
    }
  }
}
