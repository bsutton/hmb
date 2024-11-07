import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao_system.dart';
import '../../util/exceptions.dart';
import '../../widgets/hmb_toast.dart';

class Credentials {}

class XeroCredentials implements Credentials {
  XeroCredentials({
    required this.clientId,
    required this.clientSecret,
  });
  String clientId;
  String clientSecret;
}

class XeroAuth2 {
  factory XeroAuth2() {
    _instance ??= XeroAuth2._();
    return _instance!;
  }

  XeroAuth2._();

  static const redirectPath = '/xero/auth_complete';
  static XeroAuth2? _instance;

  oauth2.Client? client;
  oauth2.AuthorizationCodeGrant? grant;

  String get accessToken {
    if (client == null || client!.credentials.isExpired) {
      throw XeroException('Invalid State. Call login() first');
    }
    return client!.credentials.accessToken;
  }

  Future<void> login() async {
    final loginComplete = Completer<void>();

    final credentials = await _fetchCredentials();
    final authorizationEndpoint =
        Uri.parse('https://login.xero.com/identity/connect/authorize');
    final tokenEndpoint = Uri.parse('https://identity.xero.com/connect/token');
    final redirectUri = _getRedirectUrl();

    grant = oauth2.AuthorizationCodeGrant(
      credentials.clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: credentials.clientSecret,
    );

    final authorizationUrl = grant!.getAuthorizationUrl(
      redirectUri,
      scopes: [
        'openid',
        'profile',
        'email',
        'offline_access',
        'accounting.transactions',
        'accounting.contacts',
      ],
    );

    if (await canLaunchUrl(authorizationUrl)) {
      await launchUrl(authorizationUrl);
    }

    final appLinks = AppLinks();
// Subscribe to all events (initial link and further)
    late StreamSubscription<Uri> sub;
    sub = appLinks.uriLinkStream.listen((uri) {
      log('applink: $uri');
      if (uri.toString().startsWith(_getRedirectUrl().toString())) {
        sub.cancel();
        log('applink - matched calling completeLogin');
        completeLogin(loginComplete, uri);
      }
    });

    // Handle the redirection back to the app in `completeLogin`.
    return loginComplete.future;
  }

  Future<void> completeLogin(
      Completer<void> loginComplete, Uri responseUri) async {
    log('completeLogin with: $responseUri');
    if (grant == null) {
      log('grant not initialised');
      log('loginComplete with Error - grant not initialised');
      loginComplete.completeError('Grant not initialized');
      throw XeroException('Grant not initialized');
    }

    try {
      client =
          await grant!.handleAuthorizationResponse(responseUri.queryParameters);
      log('Login completed successfully');
      // HMBToast.info(
      //     'User logged in with access token: ${client!.credentials.accessToken}');
      log('loginComplete success');
      loginComplete.complete();
    } catch (e) {
      log('failed to complete login: $e');
      HMBToast.error('Failed to complete login: $e');
      loginComplete.completeError('Failed to complete login: $e');
    }
  }

  Future<void> refreshToken() async {
    if (client == null) {
      throw XeroException('Client not initialized');
    }

    if (client!.credentials.isExpired) {
      final refreshedClient = await client!.refreshCredentials();
      client = refreshedClient;
    }
  }

  Uri _getRedirectUrl() {
    if (kIsWeb) {
      return Uri.parse('http://localhost:22433/redirect.html');
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return Uri.parse('https://ivanhoehandyman.com.au$redirectPath');
    }
    return Uri.parse('http://localhost:12335');
  }

  Future<void> logout() async {
    client = null;
  }

  Future<XeroCredentials> _fetchCredentials() async {
    final system = await DaoSystem().get();

    if (system == null ||
        Strings.isBlank(system.xeroClientId) ||
        Strings.isBlank(system.xeroClientSecret)) {
      throw InvoiceException(
          'The Xero credentials are not set. Go to the System screen and set them.');
    }
    return XeroCredentials(
        clientId: system.xeroClientId!, clientSecret: system.xeroClientSecret!);
  }
}

void log(String text) {
  print('HMB: $text');
}
