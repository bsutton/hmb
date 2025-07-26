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
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'backup.dart';
import 'google_drive_auth.dart';

class GoogleDriveApi {
  GoogleDriveApi._internal(this._authHeaders);

  var _initialised = false;
  final Map<String, String> _authHeaders;
  late final drive.DriveApi _driveApi;
  late AuthenticatedClient? _authClient;

  drive.FilesResource get files => _driveApi.files;

  /// fromHeaders
  static Future<GoogleDriveApi> fromHeaders(
    Map<String, String> authHeaders,
  ) async {
    final api = GoogleDriveApi._internal(authHeaders);
    await api.init();
    return api;
  }

  /// selfAuth
  static Future<GoogleDriveApi> selfAuth() async {
    final auth = await GoogleDriveAuth.init();
    return GoogleDriveApi.fromHeaders(auth.authHeaders);
  }

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
