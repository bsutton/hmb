/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the
 following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third
     parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:settings_yaml/settings_yaml.dart';

import '../../../../util/flutter/paths_flutter.dart';

class GoogleDriveAuth {
  /// OAuth Client in Google Play Console: HMB-Production-Signed-By-Google
  static const _clientId =
      '''704526923643-ot7i0jpo27urkkibm1gsqpji7f2nigt3.apps.googleusercontent.com''';

  /// OAuth Client in Google Play Console: HMB for Google
  ///  Sign-in - this is the serverClientId
  static const _serverClientId =
      '''704526923643-vdu784t5s102g2uanosrd72rnv1cd795.apps.googleusercontent.com''';

  static var _initialised = false;
  static late GoogleDriveAuth _instance;

  final List<String> scopes = [drive.DriveApi.driveFileScope];

  var _signedIn = false;

  Map<String, String>? _authHeaders;

  var _awaitingAuth = Completer<GoogleAuthResult>();

  /// Make the ctor private
  /// You must call init to get the single instance.
  GoogleDriveAuth._();

  Map<String, String> get authHeaders {
    final headers = _authHeaders;
    if (!_signedIn || headers == null) {
      throw StateError(
        'Google Drive auth headers are not available. '
        'Ensure sign-in completed first.',
      );
    }
    return headers;
  }

  Future<Map<String, String>?> authHeadersOrNull() async {
    try {
      await signInIfAutomatic();
    } catch (_) {
      await _markSignedOut();
      return null;
    }
    if (!_signedIn) {
      return null;
    }
    return _authHeaders;
  }

  static Future<GoogleDriveAuth> instance() async {
    if (_initialised) {
      return _instance;
    }

    _instance = GoogleDriveAuth._();
    await _instance._initialise();

    return _instance;
  }

  /// returns true if the current platform supports google signin.
  static bool isAuthSupported() =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || kIsWeb;

  /// initialised [GoogleSignIn]
  Future<void> _initialise() async {
    final signIn = GoogleSignIn.instance;

    await signIn.initialize(
      clientId: _clientId,
      serverClientId: _serverClientId,
    );

    /// Listen for auth transitions.
    // _authSubscription =
    signIn.authenticationEvents
        .listen((event) async {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            await _handleAuthEvent(event);
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            await _markSignedOut();
          }
        })
        .onError(_handleAuthenticationError);

    /// we use the above listen code to notify signing.
    /// has restarted.
    // unawaited(this.signIn());
    _initialised = true;
  }

  /// triggers and automatic signin
  Future<void> signInIfAutomatic() async {
    if ((await hasSignedIn()) && !isSignedIn) {
      // this should trigger a silent signin.
      await signIn();
    }
  }

  bool get isSignedIn => _signedIn;

  Future<void> signIn() async {
    final signIn = GoogleSignIn.instance;

    _awaitingAuth = Completer<GoogleAuthResult>();
    if (await hasSignedIn()) {
      unawaited(signIn.attemptLightweightAuthentication());
    } else {
      /// testing on android show that a call to
      /// attemptLightweightAuthentication is always sufficient
      /// but it may be different on other platforms so as
      /// an act of caution.
      unawaited(signIn.authenticate());
    }

    await _awaitingAuth.future;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _markSignedOut();
  }

  Future<void> _handleAuthEvent(
    GoogleSignInAuthenticationEventSignIn event,
  ) async {
    final account = event.user;

    final authorization = await account.authorizationClient
        .authorizationForScopes(scopes);

    if (authorization != null) {
      await _markSignedIn();
      await _buildAuthHeaders(account);
      if (!_awaitingAuth.isCompleted) {
        _awaitingAuth.complete(GoogleAuthResult.success());
      }
      return;
    }
    await _markSignedOut();
    if (!_awaitingAuth.isCompleted) {
      _awaitingAuth.completeError(
        GoogleAuthResult.failure(
          'Google sign-in completed without Drive authorization.',
        ),
      );
    }
  }

  Future<void> _buildAuthHeaders(GoogleSignInAccount user) async {
    /// Get the access token for the driveFileScope.
    final client = await user.authorizationClient.authorizeScopes(scopes);

    _authHeaders = {'Authorization': 'Bearer ${client.accessToken}'};
  }

  Future<void> _handleAuthenticationError(Object e) async {
    await _markSignedOut();
    final errorMessage = e is GoogleSignInException
        ? _errorMessageFromSignInException(e)
        : GoogleAuthResult.failure('Unknown error: $e');

    if (!_awaitingAuth.isCompleted) {
      _awaitingAuth.completeError(errorMessage);
    }
  }

  GoogleAuthResult _errorMessageFromSignInException(
    GoogleSignInException e,
  ) => switch (e.code) {
    /// The operation was canceled by the user.
    GoogleSignInExceptionCode.canceled => GoogleAuthResult.cancelled(),

    /// The operation was interrupted for a reason other than
    /// being intentionally
    /// canceled by the user.
    GoogleSignInExceptionCode.interrupted => GoogleAuthResult.failure(
      'Sign in interrupted',
    ),

    /// The client is misconfigured.
    ///
    /// The [GoogleSignInException.description] should include details about the
    /// configuration problem.
    GoogleSignInExceptionCode.clientConfigurationError =>
      GoogleAuthResult.exception(e),

    /// The underlying auth SDK is unavailable or misconfigured.
    GoogleSignInExceptionCode.providerConfigurationError =>
      GoogleAuthResult.exception(e),

    /// UI needed to be displayed, but could not be.
    ///
    /// For example, this can be returned on Android if a call tries to show UI
    /// when no Activity is available.
    GoogleSignInExceptionCode.uiUnavailable => GoogleAuthResult.exception(e),

    /// An operation was attempted on a user who is not the current user, on a
    /// platform where the SDK only supports a single user being signed in at a
    /// time.
    GoogleSignInExceptionCode.userMismatch => GoogleAuthResult.exception(e),
    _ => GoogleAuthResult.failure(e.toString()),
  };

  Future<bool> hasSignedIn() async {
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    return settings.asBool('GoogleSignedIn');
  }

  Future<void> _markSignedIn() async {
    _signedIn = true;
    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings['GoogleSignedIn'] = true;
    await settings.save();
  }

  Future<void> _markSignedOut() async {
    _signedIn = false;
    _authHeaders = null;

    final settings = SettingsYaml.load(pathToSettings: await getSettingsPath());
    settings['GoogleSignedIn'] = false;
    await settings.save();
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}

class GoogleAuthResult {
  bool authenticated;
  final bool _wasCancelled;

  /// If the auth faile dt
  String error;

  GoogleAuthResult.success()
    : authenticated = true,
      error = '',
      _wasCancelled = false;

  GoogleAuthResult.cancelled()
    : authenticated = false,
      error = 'User Cancelled the signing',
      _wasCancelled = true;

  GoogleAuthResult.failure(this.error)
    : authenticated = false,
      _wasCancelled = false;

  GoogleAuthResult.exception(GoogleSignInException exception)
    : authenticated = false,
      _wasCancelled = exception.code == GoogleSignInExceptionCode.canceled,
      error = exception.toString();

  bool get wasCancelled => _wasCancelled;
  @override
  String toString() => error;
}
