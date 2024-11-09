import 'dart:async';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao_system.dart';
import '../../util/exceptions.dart';
import '../../widgets/hmb_toast.dart';
import 'redirect_handler.dart';

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

  static const redirectPath = 'xero/auth_complete';
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
    // If we have an existing client and it's not expired, use it.
    if (client != null && !client!.credentials.isExpired) {
      log('Access token is valid, no login required.');
      return;
    }

    // If the token is expired, attempt to refresh it.
    if (client != null && client!.credentials.isExpired) {
      try {
        log('Access token expired, attempting to refresh.');
        await refreshToken();
        log('Token refreshed successfully.');
        return;
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        log('Token refresh failed: $e. Proceeding to full login.');
      }
    }

    final loginComplete = Completer<void>();

    final credentials = await _fetchCredentials();
    final authorizationEndpoint =
        Uri.parse('https://login.xero.com/identity/connect/authorize');
    final tokenEndpoint = Uri.parse('https://identity.xero.com/connect/token');

    final redirectHandler = initRedirectHandler();

    final redirectUri = redirectHandler.redirectUri;

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

    await redirectHandler.start();

    late StreamSubscription<Uri> sub;
    sub = redirectHandler.stream.listen((uri) {
      if (uri.toString().startsWith(redirectHandler.redirectUri.toString())) {
        sub.cancel();
        redirectHandler.stop();
        log('applink - matched calling completeLogin');
        completeLogin(loginComplete, uri);
      }
    });

    /// Start the browser auth sequence
    await launchUrl(authorizationUrl);

    return loginComplete.future;
  }

  Future<void> completeLogin(
      Completer<void> loginComplete, Uri responseUri) async {
    log('completeLogin with: $responseUri');
    if (grant == null) {
      log('grant not initialized');
      loginComplete.completeError('Grant not initialized');
      throw XeroException('Grant not initialized');
    }

    try {
      client =
          await grant!.handleAuthorizationResponse(responseUri.queryParameters);
      log('Login completed successfully');
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
      client = await client!.refreshCredentials();
    }
  }

  Future<void> logout() async {
    client = null;
  }

  Future<XeroCredentials> _fetchCredentials() async {
    final system = await DaoSystem().get();

    if (system == null ||
        Strings.isBlank(system.xeroClientId) ||
        Strings.isBlank(system.xeroClientSecret)) {
      throw InvoiceException('''
The Xero credentials are not set. Go to the System screen and set them.''');
    }
    return XeroCredentials(
        clientId: system.xeroClientId!, clientSecret: system.xeroClientSecret!);
  }
}

void log(String text) {
  print('HMB: $text');
}
