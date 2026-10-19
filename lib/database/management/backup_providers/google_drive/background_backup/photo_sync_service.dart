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
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../../dao/dao_photo.dart';
import '../../../../../dao/dao_photo_delete_queue.dart';
import '../../../../../entity/entity.g.dart' show Photo;
import '../../../../../util/dart/log.dart';
import '../../../../../util/dart/paths.dart';
import '../../../database_helper.dart';
import '../../progress_update.dart';
import '../google_drive_api.dart';
import '../google_drive_auth.dart';
import 'photo_sync_params.dart';
import 'photo_sync_recovery.dart';
import 'upload_photos_in_backup.dart';

/// Used by the photo upload isolate to indicate
/// that it successfully uploaded a photo.
class PhotoUploaded {
  final int id;
  final String pathToStorageLocation;
  final int pathVersion;
  final String? cloudFileId;
  final String? cloudMd5;
  final DateTime? cloudModifiedDate;

  PhotoUploaded(
    this.id,
    this.pathToStorageLocation,
    this.pathVersion, {
    this.cloudFileId,
    this.cloudMd5,
    this.cloudModifiedDate,
  });
}

/// Used by the photo sync isolate to indicate a remote deletion completed.
class PhotoDeleted {
  final int id;

  PhotoDeleted(this.id);
}

class PhotoSyncException implements Exception {
  final String message;

  const PhotoSyncException(this.message);

  @override
  String toString() => message;
}

StreamSubscription<bool> listenForPhotoSyncSignIn({
  required Stream<bool> authStateChanges,
  required bool Function() isWaitingForSignIn,
  required bool Function() isRunning,
  required void Function() clearWaitingForSignIn,
  required Future<void> Function() start,
}) => authStateChanges.listen((signedIn) {
  if (signedIn && isWaitingForSignIn() && !isRunning()) {
    clearWaitingForSignIn();
    unawaited(start());
  }
});

class PhotoSyncService {
  static final _instance = PhotoSyncService._();
  Isolate? _isolate;
  var _waitingForSignIn = false;
  var _wakeLockHeld = false;

  final _controller = StreamController<ProgressUpdate>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  late final PhotoSyncRecovery _recovery;

  factory PhotoSyncService() => _instance;
  PhotoSyncService._() {
    _recovery = PhotoSyncRecovery(
      run: _run,
      stop: () => _isolate?.kill(priority: Isolate.immediate),
      isRecoverable: (error) => isRecoverablePhotoSyncError('$error'),
      onChanged: () => _controller.add(
        ProgressUpdate(
          _recovery.isRunning
              ? 'Starting photo sync...'
              : _waitingForSignIn
              ? 'Photo sync waiting for Google sign-in.'
              : _recovery.lastError != null
              ? isRecoverablePhotoSyncError('${_recovery.lastError}')
                    ? 'Photo sync interrupted. Retrying while the app is open: '
                          '${_recovery.lastError}'
                    : 'Photo sync failed: ${_recovery.lastError}'
              : '',
          0,
          0,
        ),
      ),
      onError: (error) {
        if (!isRecoverablePhotoSyncError('$error')) {
          _errorController.add('$error');
        }
      },
    );
    listenForPhotoSyncSignIn(
      authStateChanges: GoogleDriveAuth.authStateChanges,
      isWaitingForSignIn: () => _waitingForSignIn,
      isRunning: () => isRunning,
      clearWaitingForSignIn: () => _waitingForSignIn = false,
      start: () => _recovery.start(automatic: true),
    );
  }

  Stream<ProgressUpdate> get progressStream => _controller.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isRunning => _recovery.isRunning;
  bool get isCancelled => _recovery.isCancelled;
  bool get isPending => _recovery.isWaiting || _waitingForSignIn;
  bool get isWaitingForSignIn => _waitingForSignIn;
  String? get lastErrorSummary => _recovery.lastError?.toString();

  Future<void> start({bool retryOnFailure = true}) async {
    await _recovery.start();
    if (!retryOnFailure && _recovery.lastError != null) {
      // Callers performing a larger backup must still see the failure.
      // They explicitly opt out of background retries.
      final error = _recovery.lastError!;
      _recovery.cancel();
      throw PhotoSyncException('$error');
    }
  }

  Future<void> _run(bool Function() interrupted) async {
    if (!GoogleDriveAuth.isAuthSupported()) {
      return;
    }
    if (!await DatabaseHelper().waitUntilOpen()) {
      throw StateError("The database isn't open for photo sync");
    }
    // SQLite's last_backup_date and photo_delete_queue are the durable queue.
    // Never clear pending rows on interruption or cancellation.
    final photos = await DaoPhoto().getUnsyncedPhotos();
    final deletes = (await DaoPhotoDeleteQueue().getPendingDeleteIds())
        .map(
          (row) => PhotoDeletePayload(
            photoDeleteQueueId: row.id,
            photoId: row.photoId,
          ),
        )
        .toList();
    if (interrupted()) {
      return;
    }
    if (photos.isEmpty && deletes.isEmpty) {
      _waitingForSignIn = false;
      return;
    }
    final headers = await (await GoogleDriveAuth.instance())
        .authHeadersOrNull(allowAutomaticSignIn: false)
        .timeout(const Duration(seconds: 45));
    if (interrupted()) {
      return;
    }
    _waitingForSignIn = headers == null;
    if (headers == null) {
      _controller.add(
        ProgressUpdate('Photo sync waiting for Google sign-in.', 0, 0),
      );
      return;
    }

    final port = ReceivePort();
    final exited = Completer<void>();
    var acknowledgements = Future<void>.value();
    Object? failure;
    // One port preserves worker message/error/exit order. Acknowledgements are
    // serialized and drained before another worker reads the durable queue.
    port.listen((dynamic message) {
      if (message == null) {
        exited.complete();
      } else if (message is List) {
        failure = PhotoSyncException('${message.first}');
      } else if (message is ProgressUpdate) {
        if (!interrupted()) {
          _controller.add(message);
        }
      } else {
        acknowledgements = acknowledgements
            .then((_) async {
              if (message is PhotoUploaded) {
                await DaoPhoto().updatePhotoSyncStatus(
                  message.id,
                  cloudFileId: message.cloudFileId,
                  cloudMd5: message.cloudMd5,
                  cloudModifiedDate: message.cloudModifiedDate,
                );
              } else if (message is PhotoDeleted) {
                await DaoPhotoDeleteQueue().delete(message.id);
              }
            })
            .catchError((Object error) {
              failure = error;
            });
      }
    });
    try {
      await _enableWakeLock();
      if (interrupted()) {
        return;
      }
      final isolate = await Isolate.spawn<PhotoSyncParams>(
        _photoSyncEntry,
        PhotoSyncParams(
          sendPort: port.sendPort,
          authHeaders: headers,
          photos: photos,
          deletes: deletes,
        ),
        onError: port.sendPort,
        onExit: port.sendPort,
        paused: true,
        debugName: 'Photo Sync',
      );
      _isolate = isolate;
      if (interrupted()) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        isolate.resume(isolate.pauseCapability!);
      }
      await exited.future;
      await acknowledgements;
      if (failure != null && !interrupted()) {
        throw PhotoSyncException('$failure');
      }
    } finally {
      port.close();
      _isolate = null;
      await _releaseWakeLock();
    }
  }

  void cancelSync() {
    _waitingForSignIn = false;
    _recovery.cancel();
    _controller.add(ProgressUpdate('Photo sync cancelled.', 0, 0));
  }

  void pause() => _recovery.pause();

  Future<void> resumeIfNeeded() => _recovery.resume();

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      _wakeLockHeld = true;
    } catch (error, stackTrace) {
      Log.w(
        'Photo sync could not enable wakelock.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _releaseWakeLock() async {
    if (!_wakeLockHeld) {
      return;
    }
    try {
      await WakelockPlus.disable();
    } catch (error, stackTrace) {
      Log.w(
        'Photo sync could not release wakelock.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _wakeLockHeld = false;
    }
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

    final headers = await (await GoogleDriveAuth.instance()).authHeadersOrNull(
      allowAutomaticSignIn: false,
    );
    if (headers == null) {
      throw StateError('Google Drive auth is not available for download.');
    }
    final driveApi = await GoogleDriveApi.fromHeaders(headers);

    try {
      // -------- 1) Try by custom property (most reliable) --------
      final idStr = photoId.toString();
      final localPhoto = await DaoPhoto().getById(photoId);

      if (localPhoto?.cloudFileId case final fileId?) {
        try {
          final media =
              await driveApi.files.get(
                    fileId,
                    downloadOptions: gdrive.DownloadOptions.fullMedia,
                  )
                  as gdrive.Media;

          final file = File(pathToCacheStorage);
          final sink = file.openWrite();
          try {
            await media.stream.pipe(sink);
            return;
          } finally {
            await sink.close();
          }
        } catch (_) {
          // fallback to property/name lookup when stored file ID is stale.
        }
      }

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

bool isRecoverablePhotoSyncError(String message) {
  final lowerMessage = message.toLowerCase();
  return lowerMessage.contains('timeout') ||
      lowerMessage.contains("database isn't open") ||
      lowerMessage.contains('database_closed') ||
      lowerMessage.contains('timed out') ||
      lowerMessage.contains('socketexception') ||
      lowerMessage.contains('clientexception') ||
      lowerMessage.contains('connection closed') ||
      lowerMessage.contains('connection reset') ||
      lowerMessage.contains('connection refused') ||
      lowerMessage.contains('connection aborted') ||
      lowerMessage.contains('broken pipe') ||
      lowerMessage.contains('failed host lookup') ||
      lowerMessage.contains('network is unreachable') ||
      lowerMessage.contains('software caused connection abort');
}

bool shouldRetryPhotoSyncError(
  String message, {
  required bool retryOnFailure,
}) => retryOnFailure && isRecoverablePhotoSyncError(message);

/// In the isolate, after each successful upload, send the payload itself:
Future<void> _photoSyncEntry(PhotoSyncParams params) async {
  await uploadPhotosInBackup(
    sendPort: params.sendPort,
    authHeaders: params.authHeaders,
    photoPayloads: params.photos,
    deletePayloads: params.deletes,
  );
}
