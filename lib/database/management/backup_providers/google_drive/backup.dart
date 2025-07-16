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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../../../../ui/widgets/widgets.g.dart';

class BackupAuthGoogleScreen extends StatefulWidget {
  const BackupAuthGoogleScreen({required this.pathToBackup, super.key});

  final String pathToBackup;

  @override
  _BackupAuthGoogleScreenState createState() => _BackupAuthGoogleScreenState();
}

class _BackupAuthGoogleScreenState
    extends DeferredState<BackupAuthGoogleScreen> {
  GoogleSignInAccount? _currentUser;
  late StreamSubscription<GoogleSignInAuthenticationEvent> _authSubscription;

  @override
  Future<void> asyncInitState() async {
    super.initState();
    await _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    final signIn = GoogleSignIn.instance;

    await signIn.initialize(
      /// OAuth Client in Google Play Console: HMB-Production-Signed-By-Google
      clientId:
          '704526923643-ot7i0jpo27urkkibm1gsqpji7f2nigt3.apps.googleusercontent.com',

      /// OAuth Client in Google Play Console: HMB for Google Sign-in - this is the serverClientId
      serverClientId:
          '704526923643-vdu784t5s102g2uanosrd72rnv1cd795.apps.googleusercontent.com',
    );

    _authSubscription = signIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        setState(() {
          _currentUser = event.user;
        });
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        setState(() {
          _currentUser = null;
        });
      }
    });

    // Try silent sign-in
    try {
      await signIn.attemptLightweightAuthentication();
    } catch (_) {
      // ignore
    }

    // If no user, fall back to interactive
    if (_currentUser == null && signIn.supportsAuthenticate()) {
      try {
        final user = await signIn.authenticate(
          scopeHint: const [drive.DriveApi.driveFileScope],
        );
        setState(() {
          _currentUser = user;
        });
      } catch (e) {
        HMBToast.error('Google sign-in failed: $e');
      }
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Backup File to Google Drive'),
      automaticallyImplyLeading: false,
      actions: [
        if (_currentUser != null)
          HMBIconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: GoogleSignIn.instance.signOut,
            hint: 'Sign out of Google Drive',
          ),
      ],
    ),
    body: FutureBuilderEx(
      future: _ensureSignedIn(),
      waitingBuilder: (context) =>
          const Center(child: CircularProgressIndicator()),
      builder: (context, success) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            HMBButton(
              label: 'Upload File to Google Drive',
              hint: 'Backup your data to Google Drive, excluding photos',
              onPressed: () => unawaited(_uploadFile(context)),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _uploadFile(BuildContext context) async {
    if (_currentUser == null) {
      if (context.mounted) {
        HMBToast.info('Not signed in');
      }
      return;
    }

    final auth = await _currentUser!.authorizationClient.authorizeScopes([
      drive.DriveApi.driveFileScope,
    ]);

    final headers = {'Authorization': 'Bearer ${auth.accessToken}'};
    final client = AuthenticatedClient(http.Client(), headers);
    final driveApi = drive.DriveApi(client);

    final driveFile = drive.File()..name = basename(widget.pathToBackup);

    final localFile = File(widget.pathToBackup);
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());

    final response = await driveApi.files.create(driveFile, uploadMedia: media);
    print('Uploaded file: ${response.id}');
  }

  Future<bool> _ensureSignedIn() async => _currentUser != null;
}

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient(this._client, this._headers);
  final http.Client _client;
  final Map<String, String> _headers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
