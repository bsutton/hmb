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

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/oauth/redirect_handler.dart';
import '../../dao/dao_system.dart';
import '../../dao/system_secret_backend.dart';
import '../../dao/system_secret_backend_stub.dart'
    if (dart.library.ui) '../../dao/system_secret_backend_flutter.dart';
import '../../database/management/backup_providers/google_drive/google_drive_auth.dart';
import '../../integrations/gmail/google_desktop_oauth_secret.dart';
import '../../util/dart/exceptions.dart';
import 'gmail_redirect_handler_config.dart';

class GoogleMailAuth {
  /// Public identifier for HMB's shared Google OAuth Desktop app client.
  static const desktopClientId =
      '704526923643-klt8djil7tdulg1ab4v70qdd3ff4515p.'
      'apps.googleusercontent.com';
  static const mailScope = 'https://mail.google.com/';
  static const readScope = gmail.GmailApi.gmailReadonlyScope;
  static const _credentialsKey = 'system.smtp_gmail_oauth_credentials';
  static const _readCredentialsKey = 'system.gmail_read_oauth_credentials';
  static final _authorizationEndpoint = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );
  static final _tokenEndpoint = Uri.parse(
    'https://oauth2.googleapis.com/token',
  );

  final SystemSecretBackend _secretBackend;
  final _desktopSecret = GoogleDesktopOAuthSecret();
  Completer<void>? _desktopCancellation;
  RedirectHandler? _desktopHandler;

  GoogleMailAuth({SystemSecretBackend? secretBackend})
    : _secretBackend = secretBackend ?? createSystemSecretBackend();

  static bool isSupported() =>
      GoogleDriveAuth.isAuthSupported() || _isDesktopBrowserOAuthSupported;

  static bool get requiresDesktopOAuthClient => _isDesktopBrowserOAuthSupported;

  static bool get _isDesktopBrowserOAuthSupported =>
      kDebugMode && (Platform.isLinux || Platform.isWindows);

  Future<bool> isConnected() async => await _loadCredentials() != null;

  Future<void> disconnect() async {
    await cancelPendingAuthorization();
    await _secretBackend.delete(_credentialsKey);
    await _secretBackend.delete(_readCredentialsKey);
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

  Future<GoogleMailAccessToken> getReadAccessToken() {
    if (_isDesktopBrowserOAuthSupported) {
      return _getDesktopBrowserAccessToken(
        credentialKey: _readCredentialsKey,
        scopes: const [readScope],
        allowMailCredentials: true,
        requireConfiguredEmail: false,
      );
    }
    if (GoogleDriveAuth.isAuthSupported()) {
      return _getGoogleSignInAccessToken(
        scopes: const [readScope],
        allowMailAuthorization: true,
      );
    }
    throw HMBException('Gmail import is not available on this platform yet.');
  }

  Future<void> connect() async {
    if (!_isDesktopBrowserOAuthSupported) {
      await getAccessToken();
      return;
    }

    await _connectDesktop(
      credentialKey: _credentialsKey,
      scopes: const [mailScope],
    );
  }

  Future<void> _connectDesktop({
    required String credentialKey,
    required List<String> scopes,
  }) async {
    final identity = await _desktopIdentity();
    final handler = initRedirectHandler(GmailRedirectHandlerConfig());
    final cancellation = Completer<void>();
    _desktopCancellation = cancellation;
    _desktopHandler = handler;

    try {
      await handler.start();

      final grant = oauth2.AuthorizationCodeGrant(
        identity.clientId,
        _authorizationEndpoint,
        _tokenEndpoint,
        secret: identity.clientSecret,
        basicAuth: false,
      );
      final authorizationUrl = _addGoogleAuthorizationParameters(
        grant.getAuthorizationUrl(handler.redirectUri, scopes: scopes),
      );
      final launched = await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw HMBException('Could not launch Google OAuth authorization URL.');
      }

      late final Uri callbackUri;
      try {
        callbackUri = await Future.any([
          handler.stream.firstWhere(
            (uri) => uri.toString().startsWith(handler.redirectUri.toString()),
          ),
          cancellation.future.then<Uri>(
            (_) => throw const GoogleMailAuthorizationCancelled(),
          ),
        ]).timeout(const Duration(minutes: 5));
      } on TimeoutException {
        throw HMBException(
          'Google sign-in did not return to HMB. Complete the browser sign-in '
          'and ensure the configured Google OAuth client type is Desktop app, '
          'not Web, Android, or iOS. '
          'Expected callback: ${handler.redirectUri}',
        );
      }
      final client = await grant.handleAuthorizationResponse(
        callbackUri.queryParameters,
      );
      await _saveCredentials(credentialKey, client.credentials);
      client.close();
    } finally {
      await handler.stop();
      if (identical(_desktopCancellation, cancellation)) {
        _desktopCancellation = null;
        _desktopHandler = null;
      }
    }
  }

  Future<void> cancelPendingAuthorization() async {
    final cancellation = _desktopCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    await _desktopHandler?.stop();
  }

  Future<GoogleMailAccessToken> _getDesktopBrowserAccessToken({
    String credentialKey = _credentialsKey,
    List<String> scopes = const [mailScope],
    bool allowMailCredentials = false,
    bool requireConfiguredEmail = true,
  }) async {
    var activeCredentialKey = credentialKey;
    var credentials = await _loadCredentials(credentialKey);
    if (credentials == null && allowMailCredentials) {
      final mailCredentials = await _loadCredentials();
      if (_credentialsAllowMailRead(mailCredentials)) {
        credentials = mailCredentials;
        activeCredentialKey = _credentialsKey;
      }
    }
    if (credentials == null) {
      await _connectDesktop(credentialKey: credentialKey, scopes: scopes);
      credentials = await _loadCredentials(credentialKey);
    }
    if (credentials == null) {
      throw HMBException('Google OAuth login did not return credentials.');
    }

    if (credentials.isExpired) {
      final identity = await _desktopIdentity();
      final client = oauth2.Client(
        credentials,
        identifier: identity.clientId,
        secret: identity.clientSecret,
        basicAuth: false,
        onCredentialsRefreshed: (credentials) =>
            _saveCredentials(activeCredentialKey, credentials),
      );
      try {
        await client.refreshCredentials();
        credentials = client.credentials;
        await _saveCredentials(activeCredentialKey, credentials);
      } finally {
        client.close();
      }
    }
    return GoogleMailAccessToken(
      email: requireConfiguredEmail ? await _googleEmailAddress() : '',
      accessToken: credentials.accessToken,
    );
  }

  Future<GoogleMailAccessToken> _getGoogleSignInAccessToken({
    List<String> scopes = const [mailScope],
    bool allowMailAuthorization = false,
  }) async {
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
        await signIn.authenticate(scopeHint: scopes);
    final existingMailAuthorization = allowMailAuthorization
        ? await account.authorizationClient.authorizationForScopes(const [
            mailScope,
          ])
        : null;
    final authorization =
        existingMailAuthorization ??
        await account.authorizationClient.authorizationForScopes(scopes);
    final client =
        authorization ??
        await account.authorizationClient.authorizeScopes(scopes);

    return GoogleMailAccessToken(
      email: account.email,
      accessToken: client.accessToken,
    );
  }

  Future<_GoogleDesktopIdentity> _desktopIdentity() async {
    if (!_isDesktopBrowserOAuthSupported) {
      throw HMBException(
        'Desktop Gmail OAuth is available in development builds only.',
      );
    }
    return _GoogleDesktopIdentity(
      clientId: desktopClientId,
      clientSecret: await _desktopSecret.read(),
    );
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

  bool _credentialsAllowMailRead(oauth2.Credentials? credentials) {
    final scopes = credentials?.scopes ?? const <String>[];
    return scopes.contains(mailScope) || scopes.contains(readScope);
  }

  Future<void> _saveCredentials(
    String credentialKey,
    oauth2.Credentials credentials,
  ) async {
    await _secretBackend.write(credentialKey, credentials.toJson());
  }

  Future<oauth2.Credentials?> _loadCredentials([
    String credentialKey = _credentialsKey,
  ]) async {
    final json = await _secretBackend.read(credentialKey);
    if (Strings.isBlank(json)) {
      return null;
    }
    try {
      return oauth2.Credentials.fromJson(json!);
    } catch (_) {
      await _secretBackend.delete(credentialKey);
      return null;
    }
  }
}

class GoogleMailAuthorizationCancelled implements Exception {
  const GoogleMailAuthorizationCancelled();

  @override
  String toString() => 'Google mail authorization was cancelled.';
}

class GoogleMailAccessToken {
  const GoogleMailAccessToken({required this.email, required this.accessToken});

  final String email;
  final String accessToken;
}

class _GoogleDesktopIdentity {
  const _GoogleDesktopIdentity({
    required this.clientId,
    required this.clientSecret,
  });

  final String clientId;
  final String clientSecret;
}
