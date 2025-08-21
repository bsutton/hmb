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

import 'dart:async';

import 'package:app_links/app_links.dart';

import 'redirect_handler.dart';

/// Minimal App Link-based handler for mobile/web.
class AppLinkRedirectHandler extends RedirectHandler {
  AppLinkRedirectHandler(this.config) {
    _streamController = StreamController<Uri>.broadcast();
  }

  late final StreamController<Uri> _streamController;

  RedirectHandlerConfig config;

  @override
  Uri get redirectUri => config.redirectUri;

  late StreamSubscription<Uri> subscription;

  @override
  Future<void> start() async {
    // In a real app, you might set up a deep link plugin or rely on GoRouter
    // to capture /xero/auth_complete. If you capture the link yourself,
    // add the resulting Uri to _streamController.

    print('AppLinks start');
    final appLinks = AppLinks(); // AppLinks is singleton

    // Subscribe to all events (initial link and further)
    subscription = appLinks.uriLinkStream.listen((uri) {
      print('AppLinks recieved $uri');
      _streamController.add(uri);
    });
  }

  @override
  Future<void> stop() async {
    print('AppLinks stop');
    await subscription.cancel();
    await _streamController.close();
  }

  @override
  Stream<Uri> get stream => _streamController.stream;
}
