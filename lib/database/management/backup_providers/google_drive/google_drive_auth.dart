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

import '../../../../../util/exceptions.dart';
import '../../../../ui/widgets/hmb_toast.dart';

class GoogleDriveAuth {
  late final Map<String, String> _authHeaders;

  Map<String, String> get authHeaders => _authHeaders;

  static Future<GoogleDriveAuth> init() async {
    final api = GoogleDriveAuth();
    final account = await api._signIn();
    if (account == null) {
      throw BackupException('Google sign-in canceled.');
    }

    final auth = await account.authorizationClient.authorizeScopes([
      drive.DriveApi.driveFileScope,
    ]);

    api._authHeaders = {'Authorization': 'Bearer ${auth.accessToken}'};

    return api;
  }

  var _signedIn = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  Future<GoogleSignInAccount?> _signIn() async {
    final signIn = GoogleSignIn.instance;

    await signIn.initialize(
      /// OAuth Client in Google Play Console: HMB-Production-Signed-By-Google
      clientId:
          '704526923643-ot7i0jpo27urkkibm1gsqpji7f2nigt3.apps.googleusercontent.com',

      /// OAuth Client in Google Play Console: HMB for Google Sign-in - this is the serverClientId
      serverClientId:
          '704526923643-vdu784t5s102g2uanosrd72rnv1cd795.apps.googleusercontent.com',
    );

    /// Listen for auth transitions.
    _authSubscription = signIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _signedIn = true;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _signedIn = false;
      }
    });

    try {
      await signIn.attemptLightweightAuthentication();
    } catch (_) {
      // Ignore and try interactive auth next
    }

    if (signIn.supportsAuthenticate()) {
      return signIn.authenticate(scopeHint: [drive.DriveApi.driveFileScope]);
    }

    HMBToast.error('Google sign-in failed: no user authenticated');
    return null;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    unawaited(_authSubscription?.cancel());
    _signedIn = false;
  }

  Future<bool> get isSignedIn async => _signedIn;
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
