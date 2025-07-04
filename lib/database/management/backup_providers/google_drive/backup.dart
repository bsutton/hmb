/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:io';

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
  // ignore: library_private_types_in_public_api
  _BackupAuthGoogleScreenState createState() => _BackupAuthGoogleScreenState();
}

class _BackupAuthGoogleScreenState extends State<BackupAuthGoogleScreen> {
  GoogleSignInAccount? _currentUser;

  final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
    });
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
            onPressed: _googleSignIn.signOut,
            hint: 'Sign out of Google Drive',
          ),
      ],
    ),
    body: FutureBuilderEx(
      // ignore: discarded_futures
      future: _signin(context),
      waitingBuilder: (context) =>
          const Center(child: CircularProgressIndicator()),
      builder: (context, auth) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            HMBButton(
              label: 'Upload File to Google Drive',
              hint: 'Backup you data to Google Drive, excluding photos',
              onPressed: () => unawaited(_uploadFile(context)),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _uploadFile(BuildContext context) async {
    final authHeaders = await _currentUser?.authHeaders;
    if (authHeaders == null) {
      if (context.mounted) {
        HMBToast.info('Not signed in');
      }
      return;
    }

    final authenticateClient = AuthenticatedClient(http.Client(), authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    final driveFile = drive.File()..name = basename(widget.pathToBackup);

    final localFile = File(widget.pathToBackup);
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());

    final response = await driveApi.files.create(driveFile, uploadMedia: media);
    print('Uploaded file: ${response.id}');
  }

  Future<GoogleSignInAccount?> _signin(BuildContext context) async {
    try {
      return (await _googleSignIn.isSignedIn())
          ? _googleSignIn.signInSilently()
          : _googleSignIn.signIn();
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      HMBToast.error('Error signing in: $e');
      return null;
    }
  }
}

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient(this._client, this._headers);
  final http.Client _client;
  final Map<String, String> _headers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
