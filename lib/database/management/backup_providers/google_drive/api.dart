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

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
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

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }

  Future<bool> get isSignedIn async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();

    try {
      await signIn.attemptLightweightAuthentication();
    } catch (_) {
      return false;
    }

    final stream = signIn.authenticationEvents;
    await for (final event in stream) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final auth = await event.user.authorizationClient
            .authorizationForScopes([drive.DriveApi.driveFileScope]);
        return auth?.accessToken != null;
      }
    }

    return false;
  }

  Future<GoogleSignInAccount?> _signIn() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();

    try {
      await signIn.attemptLightweightAuthentication();
    } catch (_) {
      // Ignore and try interactive auth next
    }

    final stream = signIn.authenticationEvents;
    await for (final event in stream) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        return event.user;
      }
    }

    if (signIn.supportsAuthenticate()) {
      return signIn.authenticate(scopeHint: [drive.DriveApi.driveFileScope]);
    }

    HMBToast.error('Google sign-in failed: no user authenticated');
    return null;
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
    return GoogleDriveApi.fromHeaders(auth.authHeaders);
  }

  var _initialised = false;
  final Map<String, String> _authHeaders;
  late final drive.DriveApi _driveApi;
  late AuthenticatedClient? _authClient;

  drive.FilesResource get files => _driveApi.files;

  Future<void> init() async {
    if (!_initialised) {
      _authClient = AuthenticatedClient(http.Client(), _authHeaders);
      _driveApi = drive.DriveApi(_authClient!);
      _initialised = true;
    }
  }

  void close() {
    _authClient?.close();
    _authClient = null;
    _initialised = false;
  }

  Future<StreamedResponse> send(BaseRequest request) =>
      _authClient!.send(request);

  Future<String> getOrCreateFolderId(String name, {String? parentId}) async {
    var q =
        "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false";
    if (parentId != null) {
      q += " and '$parentId' in parents";
    }

    final res = await _driveApi.files.list(q: q);
    if (res.files case final list when list != null && list.isNotEmpty) {
      return list.first.id!;
    }

    final folderMeta = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = parentId == null ? null : <String>[parentId];

    final created = await _driveApi.files.create(folderMeta);
    return created.id!;
  }

  Future<String> _hmbFolder() async {
    var id = await getOrCreateFolderId('hmb');
    if (kDebugMode) {
      id = await getOrCreateFolderId('debug', parentId: id);
    }
    return id;
  }

  Future<String> getBackupFolder() async =>
      getOrCreateFolderId('backups', parentId: await _hmbFolder());

  Future<String> getPhotoSyncFolder() async =>
      getOrCreateFolderId('photos', parentId: await _hmbFolder());
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
