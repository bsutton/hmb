/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, 
 with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third
    parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/services/chatgpt_auth.dart
import 'dart:async';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao.g.dart';
import '../oauth/redirect_handler.dart';
import 'chat_gpt_redirect_handler_config.dart';

/// Manages OAuth2 login/refresh for ChatGPT and persists tokens in the system table.
class ChatGptAuth {
  factory ChatGptAuth() => _instance;
  ChatGptAuth._();
  static final _instance = ChatGptAuth._();

  static const _clientId = 'YOUR_CLIENT_ID';
  static final Uri _authorizationEndpoint = Uri.parse(
    'https://auth.openai.com/oauth/authorize',
  );
  static final Uri _tokenEndpoint = Uri.parse(
    'https://auth.openai.com/oauth/token',
  );
  static const _scopes = <String>['openid', 'chatgpt.extract', 'user.read'];

  late oauth2.AuthorizationCodeGrant? _grant;
  oauth2.Client? _client;

  /// Ensures the user is logged in: reuse valid token, refresh expired,
  ///  or do full OAuth.
  Future<void> login() async {
    final system = await DaoSystem().get();

    // If we already have a valid client in memory
    if (_client != null && !_client!.credentials.isExpired) {
      return;
    }

    // Try loading saved credentials from system
    if (_client == null && system.chatgptAccessToken != null) {
      _client = oauth2.Client(
        oauth2.Credentials(
          system.chatgptAccessToken!,
          refreshToken: system.chatgptRefreshToken,
          expiration: system.chatgptTokenExpiry,
        ),
        identifier: _clientId,
        onCredentialsRefreshed: (creds) async {
          await _persistCredentials(creds);
        },
      );
      if (!_client!.credentials.isExpired) {
        return;
      }
    }

    // Full OAuth2 code grant with PKCE and redirect handling
    final handler = initRedirectHandler(ChatGptRedirectHandlerConfig());
    await handler.start();

    _grant = oauth2.AuthorizationCodeGrant(
      _clientId,
      _authorizationEndpoint,
      _tokenEndpoint,
    );
    final authUrl = _grant!.getAuthorizationUrl(
      handler.redirectUri,
      scopes: _scopes,
    );

    // Launch system browser
    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch OAuth authorization URL');
    }

    // Wait for the redirect with code
    final callbackUri = await handler.stream.firstWhere(
      (uri) => uri.toString().startsWith(handler.redirectUri.toString()),
    );
    await handler.stop();

    // Complete the grant and obtain a client
    _client = await _grant!.handleAuthorizationResponse(
      callbackUri.queryParameters,
    );

    // Persist initial credentials
    await _persistCredentials(_client!.credentials);
  }

  /// Returns a valid access token, logging in or refreshing if needed.
  Future<String> getAccessToken() async {
    if (_client == null || _client!.credentials.isExpired) {
      await login();
    }
    return _client!.credentials.accessToken;
  }

  /// Stores refreshed credentials back to the system table.
  Future<void> _persistCredentials(oauth2.Credentials creds) async {
    final system = await DaoSystem().get();
    system
      ..chatgptAccessToken = creds.accessToken
      ..chatgptRefreshToken = creds.refreshToken
      ..chatgptTokenExpiry = creds.expiration;
    await DaoSystem().update(system);
  }
}
