import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'local_host_server.dart';
import 'models/app_link_redirect_handler.dart';

abstract class RedirectHandler {
  Uri get redirectUri;

  Future<void> start();
  Future<void> stop();

  Stream<Uri> get stream;
}

RedirectHandler initRedirectHandler() {
  if (kIsWeb) {
    return AppLinkRedirectHandler();
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return AppLinkRedirectHandler();
  }

  // desktop
  return LocalHostServer.self();
}
