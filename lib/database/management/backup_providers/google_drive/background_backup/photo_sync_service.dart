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
import 'dart:isolate';

import '../../../../../dao/dao_photo.dart';
import '../../progress_update.dart';
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

class PhotoSyncService {
  static final _instance = PhotoSyncService._();

  Isolate? _isolate;
  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;

  final StreamController<ProgressUpdate> _controller =
      StreamController.broadcast();

  factory PhotoSyncService() => _instance;
  PhotoSyncService._();

  Stream<ProgressUpdate> get progressStream => _controller.stream;

  bool get isRunning => _isolate != null;

  /// Kick off the sync and listen for both progress and payload messages.
  Future<void> start() async {
    final photos = await DaoPhoto().getUnsyncedPhotos();
    if (photos.isEmpty) {
      _controller.add(ProgressUpdate('No new Photos to sync', 0, 0));
      return;
    }

    final headers = (await GoogleDriveAuth.instance()).authHeaders;
    await _startSync(photos: photos, authHeaders: headers);
  }

  Future<void> _startSync({
    required List<PhotoPayload> photos,
    required Map<String, String> authHeaders,
  }) async {
    if (isRunning) {
      return;
    }

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
      }
    });

    _errorPort!.listen((error) {
      _controller.add(ProgressUpdate('Sync error: $error', 0, 0));
    });

    final params = PhotoSyncParams(
      sendPort: _receivePort!.sendPort,
      authHeaders: authHeaders,
      photos: photos,
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
}

/// In the isolate, after each successful upload, send the payload itself:
Future<void> _photoSyncEntry(PhotoSyncParams params) async {
  await uploadPhotosInBackup(
    sendPort: params.sendPort,
    authHeaders: params.authHeaders,
    photoPayloads: params.photos,
  );
  Isolate.exit();
}
