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
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../../../../ui/widgets/layout/layout.g.dart';
import '../../../../ui/widgets/text/hmb_text_themes.dart';
import '../../../../ui/widgets/widgets.g.dart';
import 'google_drive_api.dart';
import 'google_drive_auth.dart';

class BackupAuthGoogleScreen extends StatefulWidget {
  final String pathToBackup;

  const BackupAuthGoogleScreen({required this.pathToBackup, super.key});

  @override
  _BackupAuthGoogleScreenState createState() => _BackupAuthGoogleScreenState();
}

class _BackupAuthGoogleScreenState
    extends DeferredState<BackupAuthGoogleScreen> {
  late StreamSubscription<GoogleSignInAuthenticationEvent> _authSubscription;

  late GoogleDriveAuth auth;
  late bool googleDriveSupported;

  @override
  Future<void> asyncInitState() async {
    super.initState();
    googleDriveSupported = await GoogleDriveApi.isSupported();
    if (googleDriveSupported) {
      auth = await GoogleDriveAuth.instance();
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget signOut;
    if (googleDriveSupported) {
      signOut = HMBIconButton(
        icon: const Icon(Icons.exit_to_app),
        onPressed: auth.signOut,
        hint: 'Sign out of Google Drive',
      );
    } else {
      signOut = const HMBEmpty();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup File to Google Drive'),
        automaticallyImplyLeading: false,
        actions: [signOut],
      ),
      body: DeferredBuilder(
        this,
        // future: _ensureSignedIn(),
        builder: (context) => Center(
          child: HMBColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (googleDriveSupported)
                HMBButton(
                  label: 'Upload File to Google Drive',
                  hint: 'Backup your data to Google Drive, excluding photos',
                  onPressed: () => unawaited(_uploadFile(context)),
                ),
              if (!googleDriveSupported)
                const HMBTextLine('Google Drive is not supported.'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadFile(BuildContext context) async {
    if (auth.isSignedIn) {
      if (context.mounted) {
        HMBToast.info('Not signed in');
      }
      return;
    }

    // final auth = await _currentUser!.authorizationClient.authorizeScopes([
    //   drive.DriveApi.driveFileScope,
    // ]);

    final headers =
        auth.authHeaders; //  {'Authorization': 'Bearer ${auth.accessToken}'};
    final client = AuthenticatedClient(http.Client(), headers);
    final driveApi = drive.DriveApi(client);

    final driveFile = drive.File()..name = basename(widget.pathToBackup);

    final localFile = File(widget.pathToBackup);
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());

    final response = await driveApi.files.create(driveFile, uploadMedia: media);
    print('Uploaded file: ${response.id}');
  }
}

class AuthenticatedClient extends http.BaseClient {
  final http.Client _client;
  final Map<String, String> _headers;

  AuthenticatedClient(this._client, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
