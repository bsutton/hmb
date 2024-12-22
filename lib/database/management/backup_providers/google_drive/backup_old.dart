import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../../../../ui/widgets/hmb_button.dart';
import '../../../../ui/widgets/hmb_toast.dart';

class BackupAuthGoogleScreenV1 extends StatefulWidget {
  const BackupAuthGoogleScreenV1({required this.pathToBackup, super.key});

  final String pathToBackup;

  @override
  // ignore: library_private_types_in_public_api
  _BackupAuthGoogleScreenV1State createState() =>
      _BackupAuthGoogleScreenV1State();
}

class _BackupAuthGoogleScreenV1State extends State<BackupAuthGoogleScreenV1> {
  _BackupAuthGoogleScreenV1State()
      : _googleSignIn = GoogleSignIn(
          scopes: [drive.DriveApi.driveFileScope],
        );

  GoogleSignInAccount? _currentUser;

  final GoogleSignIn _googleSignIn;

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
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: _googleSignIn.signOut,
              )
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
                        onPressed: () async => _uploadFile(context),
                        label: 'Upload File to Google Drive',
                      ),
                    ],
                  ),
                )),
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
