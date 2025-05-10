import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_link_redirect_handler.dart';
import 'local_server_redirect_handler.dart';

/// Abstract for capturing OAuth redirects on different platforms.
abstract class RedirectHandler {
  /// The URI that the oauth provider should redirect to.
  Uri get redirectUri;

  /// Start listening for the OAuth callback.
  Future<void> start();

  /// Stop listening.
  Future<void> stop();

  /// A stream emitting the callback URI once Xero redirects to us.
  Stream<Uri> get stream;
}

/// Factory that picks the appropriate redirect approach based on platform.
RedirectHandler initRedirectHandler(RedirectHandlerConfig config) {
  if (kIsWeb) {
    return AppLinkRedirectHandler(config);
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return AppLinkRedirectHandler(config);
  }

  // desktop
  return LocalServerRedirectHandler(config);
}

abstract class RedirectHandlerConfig {
  int get port;
  Uri get redirectUri;
  String get redirectPath;
}
