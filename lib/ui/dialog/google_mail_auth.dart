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
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/oauth/redirect_handler.dart';
import '../../dao/dao_system.dart';
import '../../dao/system_secret_backend.dart';
import '../../dao/system_secret_backend_stub.dart'
    if (dart.library.ui) '../../dao/system_secret_backend_flutter.dart';
import '../../database/management/backup_providers/google_drive/google_drive_auth.dart';
import '../../util/dart/exceptions.dart';
import 'gmail_redirect_handler_config.dart';

class GoogleMailAuth {
  static const mailScope = 'https://mail.google.com/';
  static const _credentialsKey = 'system.smtp_gmail_oauth_credentials';
  static final _authorizationEndpoint = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );
  static final _tokenEndpoint = Uri.parse(
    'https://oauth2.googleapis.com/token',
  );

  final SystemSecretBackend _secretBackend;

  GoogleMailAuth({SystemSecretBackend? secretBackend})
    : _secretBackend = secretBackend ?? createSystemSecretBackend();

  static bool isSupported() =>
      GoogleDriveAuth.isAuthSupported() || _isDesktopBrowserOAuthSupported;

  static bool get _isDesktopBrowserOAuthSupported =>
      Platform.isLinux || Platform.isWindows;

  Future<bool> isConnected() async => await _loadCredentials() != null;

  Future<void> disconnect() async {
    await _secretBackend.delete(_credentialsKey);
    if (GoogleDriveAuth.isAuthSupported()) {
      await GoogleSignIn.instance.signOut();
    }
  }

  Future<GoogleMailAccessToken> getAccessToken() {
    if (_isDesktopBrowserOAuthSupported) {
      return _getDesktopBrowserAccessToken();
    }
    if (GoogleDriveAuth.isAuthSupported()) {
      return _getGoogleSignInAccessToken();
    }
    throw HMBException(
      'Google OAuth email is not available on this platform yet. '
      'Use password/app-password SMTP for this device.',
    );
  }

  Future<void> connect() async {
    if (!_isDesktopBrowserOAuthSupported) {
      await getAccessToken();
      return;
    }

    final identity = await _fetchDesktopIdentity();
    final handler = initRedirectHandler(GmailRedirectHandlerConfig());
    await handler.start();

    final grant = oauth2.AuthorizationCodeGrant(
      identity.clientId,
      _authorizationEndpoint,
      _tokenEndpoint,
    );
    final authorizationUrl = _addGoogleAuthorizationParameters(
      grant.getAuthorizationUrl(handler.redirectUri, scopes: const [mailScope]),
    );

    try {
      final launched = await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw HMBException('Could not launch Google OAuth authorization URL.');
      }

      final callbackUri = await handler.stream
          .firstWhere(
            (uri) => uri.toString().startsWith(handler.redirectUri.toString()),
          )
          .timeout(const Duration(minutes: 5));
      final client = await grant.handleAuthorizationResponse(
        callbackUri.queryParameters,
      );
      await _saveCredentials(client.credentials);
      client.close();
    } finally {
      await handler.stop();
    }
  }

  Future<GoogleMailAccessToken> _getDesktopBrowserAccessToken() async {
    final identity = await _fetchDesktopIdentity();
    var credentials = await _loadCredentials();
    if (credentials == null) {
      await connect();
      credentials = await _loadCredentials();
    }
    if (credentials == null) {
      throw HMBException('Google OAuth login did not return credentials.');
    }

    var client = oauth2.Client(
      credentials,
      identifier: identity.clientId,
      onCredentialsRefreshed: _saveCredentials,
    );

    try {
      if (client.credentials.isExpired) {
        client = await client.refreshCredentials();
        await _saveCredentials(client.credentials);
      }
      return GoogleMailAccessToken(
        email: await _googleEmailAddress(),
        accessToken: client.credentials.accessToken,
      );
    } finally {
      client.close();
    }
  }

  Future<GoogleMailAccessToken> _getGoogleSignInAccessToken() async {
    if (!GoogleDriveAuth.isAuthSupported()) {
      throw HMBException(
        'Google OAuth email is not available on this platform yet. '
        'Use password/app-password SMTP for this device.',
      );
    }

    await GoogleDriveAuth.instance();

    final signIn = GoogleSignIn.instance;
    final account =
        await signIn.attemptLightweightAuthentication() ??
        await signIn.authenticate(scopeHint: const [mailScope]);
    final authorization = await account.authorizationClient
        .authorizationForScopes(const [mailScope]);
    final client =
        authorization ??
        await account.authorizationClient.authorizeScopes(const [mailScope]);

    return GoogleMailAccessToken(
      email: account.email,
      accessToken: client.accessToken,
    );
  }

  Future<_GoogleDesktopIdentity> _fetchDesktopIdentity() async {
    final system = await DaoSystem().get();
    final clientId = system.smtpGoogleOAuthClientId;
    if (Strings.isBlank(clientId)) {
      throw HMBException(
        'Google OAuth requires a Desktop OAuth client ID. Configure '
        'Settings | Integrations | SMTP Email.',
      );
    }
    return _GoogleDesktopIdentity(clientId: clientId!.trim());
  }

  Future<String> _googleEmailAddress() async {
    final system = await DaoSystem().get();
    final email = system.smtpFromEmail ?? system.smtpUsername;
    if (Strings.isBlank(email)) {
      throw HMBException(
        'Google OAuth requires a from email address. Configure Settings | '
        'Integrations | SMTP Email.',
      );
    }
    return email!.trim();
  }

  Uri _addGoogleAuthorizationParameters(Uri authorizationUrl) =>
      authorizationUrl.replace(
        queryParameters: {
          ...authorizationUrl.queryParameters,
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );

  Future<void> _saveCredentials(oauth2.Credentials credentials) async {
    await _secretBackend.write(_credentialsKey, credentials.toJson());
  }

  Future<oauth2.Credentials?> _loadCredentials() async {
    final json = await _secretBackend.read(_credentialsKey);
    if (Strings.isBlank(json)) {
      return null;
    }
    try {
      return oauth2.Credentials.fromJson(json!);
    } catch (_) {
      await _secretBackend.delete(_credentialsKey);
      return null;
    }
  }
}

class GoogleMailAccessToken {
  const GoogleMailAccessToken({required this.email, required this.accessToken});

  final String email;
  final String accessToken;
}

class _GoogleDesktopIdentity {
  const _GoogleDesktopIdentity({required this.clientId});

  final String clientId;
}
