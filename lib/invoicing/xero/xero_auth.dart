// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_default_store/oidc_default_store.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_system.dart';
import '../../util/exceptions.dart';

class Credentials {}

class XeroCredentials implements Credentials {
  XeroCredentials({
    required this.clientId,
    required this.clientSecret,
  });
  String clientId;
  String clientSecret;
}

class XeroAuth {
  factory XeroAuth() {
    _instance ??= XeroAuth._();
    return _instance!;
  }

  XeroAuth._();
  static XeroAuth? _instance;

  OidcUserManager? manager;
  OidcUser? oidcUser;

  String get accessToken {
    final token = oidcUser?.token.accessToken;

    if (token == null) {
      throw XeroException('Invalid State. Call login() first');
    }

    return token;
  }

  Future<void> login() async {
    if (oidcUser == null) {
      await _init();
      // Login
      oidcUser = await manager!.loginAuthorizationCodeFlow();
      await _init();
    } else {
      // Refresh token
      await _refreshTokenIfNeeded();
    }
  }

  Future<void> _refreshTokenIfNeeded() async {
    try {
      if (_isTokenExpired()) {
        oidcUser = await manager!.refreshToken();
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      await _init();
    }
  }

  bool _isTokenExpired() {
    if (oidcUser?.token == null) {
      return true;
    }
    return oidcUser!.token.isAccessTokenAboutToExpire(now: DateTime.now());
  }

  Future<void> refreshToken(BuildContext context) async {
    if (manager == null) {
      throw XeroException('Manager not initialized');
    }

    try {
      final newUser = await manager!.refreshToken();
      oidcUser = newUser;
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      print('Failed to refresh token: $e');
      if (context.mounted) {
        await _init();
      }
    }
  }

  // Future<void> _showAuthDialog(BuildContext context) async {
  //   await showDialog<OidcUser>(
  //       context: context,
  //       builder: (context) => AlertDialog(
  //             title: const Text('Authenticate with Xero'),
  //             actions: [
  //               ElevatedButton(
  //                 onPressed: () async => _authWrapper(context),
  //                 child: const Text('Authenticate with Xero'),
  //               ),
  //               ElevatedButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 child: const Text('Cancel'),
  //               ),
  //             ],
  //           ));
  // }

  // Future<void> _authWrapper(BuildContext context) async {
  //   try {
  //     final user = await _authenticate();
  //     if (context.mounted) {
  //       Navigator.of(context).pop(user);
  //     }
  //   } on InvoiceException catch (e) {
  //     if (context.mounted) {
  //       HMBToast.error(context, e.message);
  //     }
  //     // ignore: avoid_catches_without_on_clauses
  //   } catch (e) {
  //     if (context.mounted) {
  //       HMBToast.error(context, e.toString());
  //     }
  //   }
  // }

  Future<void> _init() async {
    final _scopes = <String>[
      'openid',
      'profile',
      'email',
      'offline_access',
      'accounting.transactions',
      'accounting.contacts'
    ];

    final credentials = await _fetchCredentials();
    manager = OidcUserManager.lazy(
        discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
          Uri.parse('https://identity.xero.com'),
        ),
        clientCredentials: OidcClientAuthentication.clientSecretBasic(
            clientId: credentials.clientId,
            clientSecret: credentials.clientSecret),
        store: OidcDefaultStore(),
        settings: OidcUserManagerSettings(
          scope: _scopes,
          redirectUri: kIsWeb
              // this url must be an actual html page.
              // see the file in /web/redirect.html for an example.
              //
              // for debugging in flutter, you must run this app with --web-port 22433
              // TODO(bsutton): copy a redirect.html from the oidc project
              // somewhere and use that path here.
              ? Uri.parse('http://localhost:22433/redirect.html')
              : Platform.isIOS || Platform.isMacOS || Platform.isAndroid
                  // scheme: reverse domain name notation of your package name.
                  // path: anything.
                  ? Uri.parse('dev.onepub.handyman://app_auth_redirect')
                  : Platform.isWindows || Platform.isLinux
                      // using port 0 means that we don't care which port is used,
                      // and a random unused port will be assigned.
                      //
                      // this is safer than passing a port yourself.
                      //
                      // note that you can also pass a path like /redirect,
                      // but it's completely optional.
                      ? Uri.parse('http://localhost:12335')
                      // ? Uri.parse(
                      //     'https://au.com.ivanhoehandyman/app_auth_redirect')
                      : Uri(),
        ));

    // Initialize the manager
    await manager!.init();

    // Listen to user changes
    // manager!.userChanges().listen((user) {
    //   print('currentUser changed to $user');
    // });
  }

  Future<void> logout() async {
    await manager?.logout();
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
