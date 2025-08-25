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

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:settings_yaml/settings_yaml.dart';

import '../../../../util/paths_flutter.dart';

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

  final scopes = [drive.DriveApi.driveFileScope];

  var _signedIn = false;

  late Map<String, String> _authHeaders;

  var _awaitingAuth = Completer<GoogleAuthResult>();

  /// Make the ctor private
  /// You must call init to get the single instance.
  GoogleDriveAuth._();

  Map<String, String> get authHeaders => _authHeaders;

  static Future<GoogleDriveAuth> instance() async {
    if (_initialised) {
      return _instance;
    }

    _instance = GoogleDriveAuth._();
    await _instance._initialise();

    return _instance;
  }

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

  bool get isSignedIn => _signedIn;

  Future<void> signIn() async {
    final signIn = GoogleSignIn.instance;

    /// trigger a signin event.
    _awaitingAuth = Completer<GoogleAuthResult>();
    unawaited(signIn.attemptLightweightAuthentication());

    await _awaitingAuth.future;
  }

  /// returns true if the current platform supports google signin.
  static bool isAuthSupported() {
    try {
      return GoogleSignIn.instance.supportsAuthenticate();
      // ignore: avoid_catching_errors
    } on UnimplementedError catch (_) {}
    return false;
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
    }
    _awaitingAuth.complete(GoogleAuthResult.success());
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

    _awaitingAuth.completeError(errorMessage);
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
