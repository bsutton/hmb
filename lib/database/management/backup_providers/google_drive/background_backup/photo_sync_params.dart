// lib/src/services/photo_sync_params.dart
import 'dart:isolate';

import '../../../../../entity/photo.dart';
import '../../../../../util/photo_meta.dart';

/// A simple payload representing a photo record for syncing.
class PhotoPayload {
  const PhotoPayload({
    required this.id,
    required this.absolutePathToPhoto,
    required this.createdAt,
  });

  static Future<PhotoPayload> fromPhoto(Photo photo) async => PhotoPayload(
    id: photo.id,
    absolutePathToPhoto: await PhotoMeta.getAbsolutePath(photo),
    createdAt: photo.createdDate,
  );

  /// id of photo entity in db
  final int id;
  final String absolutePathToPhoto;
  final DateTime createdAt;
}

/// Parameters passed into the isolate for photo syncing.
class PhotoSyncParams {
  PhotoSyncParams({
    required this.sendPort,
    required this.authHeaders,
    required this.photos,
  });
  final SendPort sendPort;
  final Map<String, String> authHeaders;
  final List<PhotoPayload> photos;
}
