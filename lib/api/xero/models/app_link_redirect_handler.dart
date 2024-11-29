import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../redirect_handler.dart';
import '../xero_auth.dart';

class AppLinkRedirectHandler extends RedirectHandler {
  final appLinks = AppLinks();
  @override
  Future<void> start() async {}

  @override
  Uri get redirectUri {
    if (kIsWeb) {
      return Uri.parse('http://localhost:22433/redirect.html');
    }

    /// android and IOS
    return Uri.parse(
        'https://ivanhoehandyman.com.au/${XeroAuth2.redirectPath}');
  }

  @override
  Stream<Uri> get stream => appLinks.uriLinkStream;

  @override
  Future<void> stop() async {}
}
