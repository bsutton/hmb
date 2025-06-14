import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/drive/v3.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '../../../../../util/exceptions.dart';
import '../../../../ui/widgets/hmb_toast.dart';
import 'backup.dart';

class GoogleDriveAuth {
  late final Map<String, String> _authHeaders;

  Map<String, String> get authHeaders => _authHeaders;

  static Future<GoogleDriveAuth> init() async {
    final api = GoogleDriveAuth();

    // Use signInOnline for desktop platforms
    final account = await api._signin();
    if (account == null) {
      throw BackupException('Google sign-in canceled.');
    }

    api._authHeaders = await account.authHeaders;

    return api;
  }

  Future<bool> get isSignedIn async {
    if (Platform.isLinux || Platform.isWindows) {
      /// auth not supported on these plaforms.
      return false;
    }
    final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

    return googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> _signin() async {
    final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

    try {
      return (await googleSignIn.isSignedIn())
          ? googleSignIn.signInSilently()
          : googleSignIn.signIn();
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      HMBToast.error('Error signing in: $e');
      return null;
    }
  }
}

class GoogleDriveApi {
  GoogleDriveApi._internal(this._authHeaders);

  static Future<GoogleDriveApi> fromHeaders(
    Map<String, String> authHeaders,
  ) async {
    final api = GoogleDriveApi._internal(authHeaders);
    await api.init();
    return api;
  }

  static Future<GoogleDriveApi> selfAuth() async {
    final auth = await GoogleDriveAuth.init();

    final api = await GoogleDriveApi.fromHeaders(auth.authHeaders);
    await api.init();
    return api;
  }

  var _initialised = false;
  final Map<String, String> _authHeaders;
  late final drive.DriveApi _driveApi;
  late AuthenticatedClient? _authClient;

  FilesResource get files => _driveApi.files;

  Future<void> init() async {
    if (!_initialised) {
      _authClient = AuthenticatedClient(http.Client(), _authHeaders);

      // final authHeaders = await account.authHeaders;
      // final authenticateClient = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(_authClient!);
      _initialised = true;
    }
  }

  void close() {
    _authClient?.close();
    _authClient = null;
    _initialised = false;
  }

  /// Sends an HTTP request and asynchronously returns the response.
  Future<StreamedResponse> send(BaseRequest request) =>
      _authClient!.send(request);

  Future<String> getOrCreateFolderId(
    String folderName, {
    String? parentFolderId,
  }) async {
    var q =
        "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
    if (parentFolderId != null) {
      q += " and '$parentFolderId' in parents";
    }

    final folders = await _driveApi.files.list(q: q);
    if (folders.files != null && folders.files!.isNotEmpty) {
      return folders.files!.first.id!;
    } else {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      if (parentFolderId != null) {
        folder.parents = [parentFolderId];
      }
      final createdFolder = await _driveApi.files.create(folder);
      return createdFolder.id!;
    }
  }

  Future<String> getBackupFolder() async {
    var parentFolderId = await getOrCreateFolderId('hmb');

    if (kDebugMode) {
      parentFolderId = await getOrCreateFolderId(
        'debug',
        parentFolderId: parentFolderId,
      );
    }
    final backupsFolderId = await getOrCreateFolderId(
      'backups',
      parentFolderId: parentFolderId,
    );
    return backupsFolderId;
  }
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
