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
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao_system.dart';
import '../../ui/widgets/hmb_toast.dart';
import '../../util/dart/exceptions.dart';
import 'redirect_handler.dart';

/// Thrown when Xero OAuth is misused or not fully initialized
class XeroException implements Exception {
  final String message;

  XeroException(this.message);

  @override
  String toString() => 'XeroException: $message';
}

/// Holds the Xero clientId/clientSecret from your database/system config.
class XeroSecretIdentity {
  final String clientId;
  final String clientSecret;

  XeroSecretIdentity({required this.clientId, required this.clientSecret});
}

/// Manages Xero OAuth2 login, refresh, and logout.
class XeroAuth2 {
  /// somewhere to store credentials so we don't have to
  /// auth every time
  static const _credentialsKey = 'xero_credentials';
  final _secureStorage = const FlutterSecureStorage();

  /// The path suffix for finalizing OAuth.
  /// Desktop will use `http://localhost:<port>/xero/auth_complete`
  /// Mobile deep link will use https://ivanhoehandyman.com.au/xero/auth_complete
  static const redirectPath = 'xero/auth_complete';

  /// A static reference to the singleton instance.
  static XeroAuth2? _instance;

  /// The OAuth2 client once logged in.
  oauth2.Client? client;

  /// The authorization code grant flow reference.
  oauth2.AuthorizationCodeGrant? grant;

  Completer<void>? _loginCompleter;
  var _authorizationResponseHandled = false;

  factory XeroAuth2() {
    _instance ??= XeroAuth2._();
    return _instance!;
  }

  XeroAuth2._();

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
  /// 3) Otherwise, does a full OAuth flow (desktop=local
  /// server, mobile=app link).
  Future<bool> login({bool allowInteractive = true}) async {
    if (await isLoggedIn()) {
      return true;
    }
    if (!allowInteractive) {
      log('Silent login requested, but no valid Xero credentials are ready.');
      return false;
    }
    if (_loginCompleter != null) {
      log('Login already in progress, waiting for existing flow.');
      await _loginCompleter!.future;
      return client != null && !client!.credentials.isExpired;
    }
    log('No valid saved credentials, starting full OAuth flow.');

    final loginComplete = Completer<void>();
    _loginCompleter = loginComplete;
    _authorizationResponseHandled = false;

    final credentials = await _fetchSecretIdentity();

    final authorizationEndpoint = Uri.parse(
      'https://login.xero.com/identity/connect/authorize',
    );
    final tokenEndpoint = Uri.parse('https://identity.xero.com/connect/token');

    final redirectHandler = initRedirectHandler(); // mobile or desktop

    final redirectUri = redirectHandler.redirectUri;

    grant = oauth2.AuthorizationCodeGrant(
      credentials.clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: credentials.clientSecret,
      codeVerifier: _generateCodeVerifier(),
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
      if (_authorizationResponseHandled) {
        return;
      }
      if (uri.toString().startsWith(redirectUri.toString())) {
        _authorizationResponseHandled = true;
        unawaited(sub.cancel());
        unawaited(redirectHandler.stop());
        log('Received callback -> calling completeLogin');
        unawaited(completeLogin(loginComplete, uri));
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

    try {
      await loginComplete.future;
      return true;
    } finally {
      _loginCompleter = null;
      _authorizationResponseHandled = false;
    }
  }

  /// Completes the authorization, exchanging the code for a token.
  Future<void> completeLogin(
    Completer<void> loginComplete,
    Uri responseUri,
  ) async {
    log('Completing Xero OAuth callback');
    if (loginComplete.isCompleted) {
      log('Ignoring duplicate Xero callback.');
      return;
    }
    if (grant == null) {
      log('Grant not initialized');
      loginComplete.completeError('Grant not initialized');
      throw XeroException('Grant not initialized');
    }
    try {
      client = await grant!.handleAuthorizationResponse(
        responseUri.queryParameters,
      );
      grant = null;
      await _saveCredentials(client!.credentials); // Save the credentials
      log('Login completed successfully');
      loginComplete.complete();
    } catch (e) {
      log('Failed to complete login: $e');
      HMBToast.error('Failed to complete login: $e');
      grant = null;
      if (!loginComplete.isCompleted) {
        loginComplete.completeError(e);
      }
    }
  }

  /// Refreshes the token if expired.
  Future<void> refreshToken() async {
    if (client == null) {
      throw XeroException('Client not initialized');
    }
    if (client!.credentials.isExpired) {
      client = await client!.refreshCredentials();
      await _saveCredentials(client!.credentials); // Save refreshed credentials
    }
  }

  /// Logs out by clearing the client.
  Future<void> logout() async {
    client = null;
    await _clearSavedCredentials();
  }

  /// Generates a cryptographically random PKCE code verifier.
  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Loads the Xero client credentials from your database/system settings.
  Future<XeroSecretIdentity> _fetchSecretIdentity() async {
    final system = await DaoSystem().get();

    if (Strings.isBlank(system.xeroClientId) ||
        Strings.isBlank(system.xeroClientSecret)) {
      throw InvoiceException(
        '''
The Xero credentials are not set. Navigate to the System | Integration screen and set them.''',
      );
    }
    return XeroSecretIdentity(
      clientId: system.xeroClientId!,
      clientSecret: system.xeroClientSecret!,
    );
  }

  Future<void> _saveCredentials(oauth2.Credentials credentials) async {
    await _secureStorage.write(
      key: _credentialsKey,
      value: credentials.toJson(),
    );
  }

  Future<oauth2.Credentials?> _loadSavedCredentials() async {
    final json = await _secureStorage.read(key: _credentialsKey);
    if (json == null) {
      return null;
    }
    try {
      return oauth2.Credentials.fromJson(json);
    } catch (e) {
      log('Failed to parse saved credentials: $e');
      return null;
    }
  }

  Future<void> _clearSavedCredentials() async {
    await _secureStorage.delete(key: _credentialsKey);
  }

  /// Check if we have saved credentials or a refresh
  /// token or simply that the client is already valid.
  Future<bool> isLoggedIn() async {
    final savedCredentials = await _loadSavedCredentials();

    // If we have an existing client and it's not expired, use it.
    if (client != null && !client!.credentials.isExpired) {
      log('Access token is valid, no login required.');
      return true;
    }

    if (savedCredentials != null) {
      final credentials = await _fetchSecretIdentity();

      client = oauth2.Client(
        savedCredentials,
        identifier: credentials.clientId,
        secret: credentials.clientSecret,
      );
      if (!client!.credentials.isExpired) {
        log('Loaded saved credentials, no login required.');
        return true;
      } else {
        try {
          log('Saved credentials expired, attempting to refresh.');
          await refreshToken();
          log('Token refreshed successfully.');
          await _saveCredentials(client!.credentials);
          return true;
        } catch (e) {
          log('Token refresh failed: $e. Proceeding to full login.');
        }
      }
    }
    return false;
  }
}

void log(String text) {
  print('HMB: $text');
}
