/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/services/photo_sync_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dcli_core/dcli_core.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:path/path.dart' as p;

import '../../../../../dao/dao_photo.dart';
import '../../../../../dao/dao_photo_delete_queue.dart';
import '../../../../../entity/entity.g.dart' show Photo;
import '../../../../../util/dart/paths.dart';
import '../../progress_update.dart';
import '../google_drive_api.dart';
import '../google_drive_auth.dart';
import 'photo_sync_params.dart';
import 'upload_photos_in_backup.dart';

/// Used by the photo upload isolate to indicate
/// that it successfully uploaded a photo.
class PhotoUploaded {
  final int id;
  final String pathToStorageLocation;
  final int pathVersion;

  PhotoUploaded(this.id, this.pathToStorageLocation, this.pathVersion);
}

/// Used by the photo sync isolate to indicate a remote deletion completed.
class PhotoDeleted {
  final int id;

  PhotoDeleted(this.id);
}

class PhotoSyncService {
  static final _instance = PhotoSyncService._();
  static const _maxAutoRetries = 3;
  static const _retryDelay = Duration(seconds: 3);

  Isolate? _isolate;
  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  Timer? _retryTimer;
  var _autoRetryAttempts = 0;
  var _syncHadError = false;

  final StreamController<ProgressUpdate> _controller =
      StreamController.broadcast();

  factory PhotoSyncService() => _instance;
  PhotoSyncService._();

  Stream<ProgressUpdate> get progressStream => _controller.stream;

  bool get isRunning => _isolate != null;

  /// Kick off the sync and listen for both progress and payload messages.
  Future<void> start() async {
    final photos = await DaoPhoto().getUnsyncedPhotos();
    final deletes = (await DaoPhotoDeleteQueue().getPendingDeleteIds())
        .map(
          (photoDeleteQueue) => PhotoDeletePayload(
            photoDeleteQueueId: photoDeleteQueue.id,
            photoId: photoDeleteQueue.photoId,
          ),
        )
        .toList();
    if (photos.isEmpty && deletes.isEmpty) {
      _autoRetryAttempts = 0;
      _controller.add(ProgressUpdate('No new Photos to sync', 0, 0));
      return;
    }

    final headers = await (await GoogleDriveAuth.instance())
        .authHeadersOrNull();
    if (headers == null) {
      _controller.add(
        ProgressUpdate('Photo sync waiting for Google sign-in.', 0, 0),
      );
      return;
    }
    await _startSync(photos: photos, deletes: deletes, authHeaders: headers);
  }

  Future<void> _startSync({
    required List<PhotoPayload> photos,
    required List<PhotoDeletePayload> deletes,
    required Map<String, String> authHeaders,
  }) async {
    if (isRunning) {
      return;
    }
    _syncHadError = false;

    _receivePort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    // 1️⃣ Listen for ProgressUpdate or PhotoPayload
    _receivePort!.listen((message) async {
      if (message is ProgressUpdate) {
        _controller.add(message);
      } else if (message is PhotoUploaded) {
        // mark that one photo has now been backed up
        await DaoPhoto().updatePhotoSyncStatus(message.id);
      } else if (message is PhotoDeleted) {
        await DaoPhotoDeleteQueue().delete(message.id);
      }
    });

    _errorPort!.listen(_onSyncError);

    final params = PhotoSyncParams(
      sendPort: _receivePort!.sendPort,
      authHeaders: authHeaders,
      photos: photos,
      deletes: deletes,
    );

    _isolate = await Isolate.spawn<PhotoSyncParams>(
      _photoSyncEntry,
      params,
      onError: _errorPort!.sendPort,
      onExit: _exitPort!.sendPort,
      debugName: 'Photo Sync',
    );

    await _exitPort!.first;
    _cleanup();
    if (_syncHadError) {
      _scheduleRetry();
    } else {
      _autoRetryAttempts = 0;
    }
  }

  void cancelSync() {
    _isolate?.kill(priority: Isolate.immediate);
    _cleanup();
  }

  void _cleanup() {
    _receivePort?.close();
    _errorPort?.close();
    _exitPort?.close();
    _isolate = null;
    _receivePort = null;
    _errorPort = null;
    _exitPort = null;
  }

  void _onSyncError(dynamic error) {
    _syncHadError = true;
    _controller.add(
      ProgressUpdate(
        'Photo sync interrupted due to communication error.',
        0,
        0,
      ),
    );
  }

  void _scheduleRetry() {
    if (_autoRetryAttempts >= _maxAutoRetries) {
      _controller.add(
        ProgressUpdate(
          'Photo sync paused. It will resume when the app is reopened.',
          0,
          0,
        ),
      );
      return;
    }

    _autoRetryAttempts++;
    _controller.add(
      ProgressUpdate(
        'Retrying photo sync ($_autoRetryAttempts/$_maxAutoRetries)...',
        0,
        0,
      ),
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      unawaited(start());
    });
  }

  Future<void> resumeIfNeeded() async {
    if (isRunning) {
      return;
    }
    final photos = await DaoPhoto().getUnsyncedPhotos();
    final deletes = await DaoPhotoDeleteQueue().getPendingDeleteIds();
    if (photos.isEmpty && deletes.isEmpty) {
      return;
    }
    _controller.add(ProgressUpdate('Resuming photo sync...', 0, 0));
    await start();
  }

  /// Downloads the original image for the [Photo] with [photoId] from
  /// Google Drive and saves it to
  /// [pathToCacheStorage]. Overwrites any existing file
  /// at [pathToCacheStorage].
  ///
  /// Lookup strategy:
  ///  1) Query by custom Drive file
  ///     property: properties.photoId == meta.photo.id
  ///  2) Fallback: name starts with `<id>:` (as used during upload)
  ///
  /// Throws if the file cannot be found or download fails.
  Future<void> download(
    int photoId,
    Path pathToCacheStorage,
    Path pathToCloudStorage,
  ) async {
    // Ensure output dir exists.
    final outDir = p.dirname(pathToCacheStorage);
    if (!exists(outDir)) {
      createDir(outDir, recursive: true);
    }

    final headers = await (await GoogleDriveAuth.instance())
        .authHeadersOrNull();
    if (headers == null) {
      throw StateError('Google Drive auth is not available for download.');
    }
    final driveApi = await GoogleDriveApi.fromHeaders(headers);

    try {
      // -------- 1) Try by custom property (most reliable) --------
      final idStr = photoId.toString();
      // Drive v3 query: "properties has { key='photoId' and value='123' }"
      // also ensure it's not in trash.
      final qByProp = '''
properties has { key='photoId' and value='$idStr' } and trashed=false''';

      var match = await _findSingleFile(driveApi: driveApi, q: qByProp);

      // -------- 2) Fallback: by name prefix "<id>:" --------
      if (match == null) {
        // We uploaded with name "${photoPayload.id}:<basename>"
        final qByName = "name contains '$idStr:' and trashed=false";
        match = await _findSingleFile(driveApi: driveApi, q: qByName);
      }

      if (match == null || match.id == null) {
        throw StateError(
          'Photo $photoId not found in Drive (by property or name).',
        );
      }

      // -------- Download full media stream and save --------
      final media =
          await driveApi.files.get(
                match.id!,
                downloadOptions: gdrive.DownloadOptions.fullMedia,
              )
              as gdrive.Media;

      final file = File(pathToCacheStorage);
      final sink = file.openWrite();
      try {
        await media.stream.pipe(sink);
      } finally {
        await sink.close();
      }
    } finally {
      driveApi.close();
    }
  }

  // Helper to find a single Drive file for a query,
  // limiting fields to keep payload small.
  Future<gdrive.File?> _findSingleFile({
    required GoogleDriveApi driveApi,
    required String q,
  }) async {
    final res = await driveApi.files.list(
      q: q,
      $fields: 'files(id, name, size, properties), nextPageToken',
      pageSize: 10, // tiny page; we expect one
    );
    final files = res.files ?? const <gdrive.File>[];
    if (files.isEmpty) {
      return null;
    }

    // If multiple (shouldn’t happen), prefer the most recent by name or first.
    if (files.length == 1) {
      return files.first;
    }
    // Choose deterministically: assume latest one is fine.
    // (You could sort by modifiedTime if you request that field.)
    return files.first;
  }
}

/// In the isolate, after each successful upload, send the payload itself:
Future<void> _photoSyncEntry(PhotoSyncParams params) async {
  await uploadPhotosInBackup(
    sendPort: params.sendPort,
    authHeaders: params.authHeaders,
    photoPayloads: params.photos,
    deletePayloads: params.deletes,
  );
  Isolate.exit();
}
