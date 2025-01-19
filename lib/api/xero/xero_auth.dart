import 'dart:async';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao_system.dart';
import '../../ui/widgets/hmb_toast.dart';
import '../../util/exceptions.dart';
import 'redirect_handler.dart';

/// Thrown when Xero OAuth is misused or not fully initialized
class XeroException implements Exception {
  XeroException(this.message);
  final String message;

  @override
  String toString() => 'XeroException: $message';
}

/// Holds the Xero clientId/clientSecret from your database/system config.
class XeroCredentials {
  XeroCredentials({
    required this.clientId,
    required this.clientSecret,
  });
  final String clientId;
  final String clientSecret;
}

/// Manages Xero OAuth2 login, refresh, and logout.
class XeroAuth2 {
  factory XeroAuth2() {
    _instance ??= XeroAuth2._();
    return _instance!;
  }

  XeroAuth2._();

  /// The path suffix for finalizing OAuth.
  /// Desktop will use http://localhost:<port>/xero/auth_complete
  /// Mobile deep link will use https://ivanhoehandyman.com.au/xero/auth_complete
  static const redirectPath = 'xero/auth_complete';

  /// A static reference to the singleton instance.
  static XeroAuth2? _instance;

  /// The OAuth2 client once logged in.
  oauth2.Client? client;

  /// The authorization code grant flow reference.
  oauth2.AuthorizationCodeGrant? grant;

  /// Access token getter, throws if not valid.
  String get accessToken {
    if (client == null || client!.credentials.isExpired) {
      throw XeroException('Invalid state. Call login() first.');
    }
    return client!.credentials.accessToken;
  }

  /// Tries to log in to Xero:
  /// 1) Reuses a valid token, if available.
  /// 2) Otherwise, tries to refresh if expired.
  /// 3) Otherwise, does a full OAuth flow (desktop=local server, mobile=app link).
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

    final redirectHandler = initRedirectHandler(); // mobile or desktop

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
      if (uri.toString().startsWith(redirectUri.toString())) {
        sub.cancel();
        redirectHandler.stop();
        log('Received callback -> calling completeLogin');
        completeLogin(loginComplete, uri);
      }
    });

    final canLaunch = await launchUrl(
      authorizationUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!canLaunch) {
      log('Could not launch $authorizationUrl');
      loginComplete.completeError('Could not launch $authorizationUrl');
    }

    await loginComplete.future;
  }

  /// Completes the authorization, exchanging the code for a token.
  Future<void> completeLogin(
      Completer<void> loginComplete, Uri responseUri) async {
    log('completeLogin with: $responseUri');
    if (grant == null) {
      log('Grant not initialized');
      loginComplete.completeError('Grant not initialized');
      throw XeroException('Grant not initialized');
    }
    try {
      client =
          await grant!.handleAuthorizationResponse(responseUri.queryParameters);
      log('Login completed successfully');
      loginComplete.complete();
    } catch (e) {
      log('Failed to complete login: $e');
      HMBToast.error('Failed to complete login: $e');
      loginComplete.completeError(e);
    }
  }

  /// Refreshes the token if expired.
  Future<void> refreshToken() async {
    if (client == null) {
      throw XeroException('Client not initialized');
    }
    if (client!.credentials.isExpired) {
      client = await client!.refreshCredentials();
    }
  }

  /// Logs out by clearing the client.
  Future<void> logout() async {
    client = null;
  }

  /// Loads the Xero client credentials from your database/system settings.
  Future<XeroCredentials> _fetchCredentials() async {
    final system = await DaoSystem().get();

    if (Strings.isBlank(system.xeroClientId) ||
        Strings.isBlank(system.xeroClientSecret)) {
      throw InvoiceException('''
The Xero credentials are not set. Navigate to the System | Integration screen and set them.''');
    }
    return XeroCredentials(
      clientId: system.xeroClientId!,
      clientSecret: system.xeroClientSecret!,
    );
  }
}

void log(String text) {
  print('HMB: $text');
}
