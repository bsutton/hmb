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

// lib/src/services/photo_sync_params.dart
import 'dart:isolate';

import '../../../../../entity/photo.dart';
import '../../../../../util/dart/photo_meta.dart';

/// A simple payload representing a photo record for syncing.
class PhotoPayload {
  /// id of photo entity in db
  final int id;

  /// Where the photo is stored on the device.
  final String absolutePathToLocalPhoto;
  final DateTime createdAt;

  /// The path to the cloud storage where this photo
  /// will be stored.
  /// This path is relative to the 'hmb/photo' folder.
  /// In debug mode it will be relative to 'hmb/debug/photo'.
  final String pathToCloudStorage;

  const PhotoPayload({
    required this.id,
    required this.absolutePathToLocalPhoto,
    required this.createdAt,
    required this.pathToCloudStorage,
  });

  static Future<PhotoPayload> fromPhoto(Photo photo) async {
    final meta = PhotoMeta.fromPhoto(photo: photo);

    final absolutePathToPhoto = await PhotoMeta.getAbsolutePath(photo);
    return PhotoPayload(
      id: photo.id,
      absolutePathToLocalPhoto: absolutePathToPhoto,
      createdAt: photo.createdDate,
      pathToCloudStorage: await meta.cloudStoragePath,
    );
  }
}

/// A simple payload representing a photo deletion request.
class PhotoDeletePayload {
  final int photoDeleteQueueId;
  final int photoId;

  const PhotoDeletePayload({
    required this.photoDeleteQueueId,
    required this.photoId,
  });
}

/// Parameters passed into the isolate for photo syncing.
class PhotoSyncParams {
  final SendPort sendPort;
  final Map<String, String> authHeaders;
  final List<PhotoPayload> photos;
  final List<PhotoDeletePayload> deletes;

  PhotoSyncParams({
    required this.sendPort,
    required this.authHeaders,
    required this.photos,
    required this.deletes,
  });
}
