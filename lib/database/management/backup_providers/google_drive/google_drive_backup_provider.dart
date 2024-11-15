import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite_common/sqflite.dart' as sql;

import '../../../../../util/exceptions.dart';
import '../../../../../util/paths.dart'
    if (dart.library.ui) '../../../../util/paths_flutter.dart';
import '../../../../widgets/hmb_toast.dart';
import '../backup_provider.dart';

class GoogleDriveBackupProvider extends BackupProvider {
  GoogleDriveBackupProvider(super.databaseFactory);

  @override
  String get name => 'Google Drive Backup';

  late GoogleSignIn _googleSignIn;

  Future<drive.DriveApi> getDriveApi() async {
    _googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveFileScope],
    );

    // Use signInOnline for desktop platforms
    final account = await _signin();
    if (account == null) {
      throw BackupException('Google sign-in canceled.');
    }

    final authHeaders = await account.authHeaders;
    final authenticateClient = AuthenticatedClient(http.Client(), authHeaders);

    // final authHeaders = await account.authHeaders;
    // final authenticateClient = GoogleAuthClient(authHeaders);
    return drive.DriveApi(authenticateClient);
  }

  Future<GoogleSignInAccount?> _signin() async {
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

  Future<String> getOrCreateFolderId(String folderName,
      {String? parentFolderId}) async {
    final driveApi = await getDriveApi();
    var q =
        "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
    if (parentFolderId != null) {
      q += " and '$parentFolderId' in parents";
    }

    final folders = await driveApi.files.list(q: q);
    if (folders.files != null && folders.files!.isNotEmpty) {
      return folders.files!.first.id!;
    } else {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      if (parentFolderId != null) {
        folder.parents = [parentFolderId];
      }
      final createdFolder = await driveApi.files.create(folder);
      return createdFolder.id!;
    }
  }

  @override
  Future<void> deleteBackup(Backup backupToDelete) async {
    try {
      final driveApi = await getDriveApi();
      final hmbFolderId = await getOrCreateFolderId('hmb');
      final backupsFolderId =
          await getOrCreateFolderId('backups', parentFolderId: hmbFolderId);

      final fileName = basename(backupToDelete.pathTo);
      final q = """
'$backupsFolderId' in parents and name='$fileName' and trashed=false""";

      final filesList = await driveApi.files.list(q: q);
      final files = filesList.files ?? [];

      if (files.isEmpty) {
        throw BackupException('Backup file not found: $fileName');
      }

      final fileId = files.first.id;
      await driveApi.files.delete(fileId!);
    } catch (e) {
      throw BackupException('Error deleting backup from Google Drive: $e');
    }
  }

  @override
  Future<File> fetchBackup(String pathToBackupInStorage) async {
    try {
      final driveApi = await getDriveApi();
      final hmbFolderId = await getOrCreateFolderId('hmb');
      final backupsFolderId =
          await getOrCreateFolderId('backups', parentFolderId: hmbFolderId);

      final q = """
'$backupsFolderId' in parents and name='$pathToBackupInStorage' and trashed=false""";
      final filesList = await driveApi.files.list(q: q);
      final files = filesList.files ?? [];

      if (files.isEmpty) {
        throw BackupException('Backup file not found: $pathToBackupInStorage');
      }

      final fileId = files.first.id!;
      final media = (await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      )) as drive.Media;

      return saveStreamToFile(media.stream, createTempFile());
    } catch (e) {
      throw BackupException('Error downloading backup from Google Drive: $e');
    }
  }

  Future<File> saveStreamToFile(
      Stream<List<int>> stream, String filePath) async {
    // Open the file in write mode
    final file = File(filePath);
    final sink = file.openWrite();

    try {
      // Pipe the stream into the file sink
      await stream.pipe(sink);
    } finally {
      // Ensure the sink is closed to save the file
      await sink.close();
    }

    return File(filePath);
  }

  @override
  Future<List<String>> getBackups() async {
    try {
      final driveApi = await getDriveApi();
      final hmbFolderId = await getOrCreateFolderId('hmb');
      final backupsFolderId =
          await getOrCreateFolderId('backups', parentFolderId: hmbFolderId);

      final q = "'$backupsFolderId' in parents and trashed=false";
      final filesList = await driveApi.files.list(q: q);
      final backupFiles = filesList.files ?? [];

      return backupFiles.map((file) => file.name ?? 'Unknown').toList();
    } catch (e) {
      throw BackupException('Error listing backups from Google Drive: $e');
    }
  }

  @override
  Future<BackupResult> store(
      {required String pathToDatabaseCopy,
      required String pathToZippedBackup,
      required int version}) async {
    try {
      final driveApi = await getDriveApi();
      final hmbFolderId = await getOrCreateFolderId('hmb');
      final backupsFolderId =
          await getOrCreateFolderId('backups', parentFolderId: hmbFolderId);

      final fileToUpload = File(pathToZippedBackup);
      final fileName = basename(pathToZippedBackup);
      final file = drive.File()
        ..name = fileName
        ..parents = [backupsFolderId];

      final media =
          drive.Media(fileToUpload.openRead(), fileToUpload.lengthSync());
      await driveApi.files.create(file, uploadMedia: media);

      return BackupResult(
        pathToSource: pathToDatabaseCopy,
        pathToBackup: pathToZippedBackup,
        success: true,
      );
    } catch (e) {
      throw BackupException('Error uploading backup to Google Drive: $e');
    }
  }

  @override
  Future<String> get photosRootPath => getPhotosRootPath();

  @override
  Future<String> get databasePath async =>
      join(await sql.getDatabasesPath(), 'handyman.db');
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient(this._client, this._headers);
  final http.Client _client;
  final Map<String, String> _headers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
}
