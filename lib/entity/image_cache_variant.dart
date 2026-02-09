/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'entity.dart';

/// Tracks a cached image variant for a photo.
class ImageCacheVariant extends Entity<ImageCacheVariant> {
  final int photoId;
  final String variant;
  final String fileName;
  final int size;
  final DateTime lastAccess;

  ImageCacheVariant._({
    required super.id,
    required this.photoId,
    required this.variant,
    required this.fileName,
    required this.size,
    required this.lastAccess,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  ImageCacheVariant.forInsert({
    required this.photoId,
    required this.variant,
    required this.fileName,
    required this.size,
    required this.lastAccess,
  }) : super.forInsert();

  ImageCacheVariant copyWith({
    int? photoId,
    String? variant,
    String? fileName,
    int? size,
    DateTime? lastAccess,
  }) => ImageCacheVariant._(
    id: id,
    photoId: photoId ?? this.photoId,
    variant: variant ?? this.variant,
    fileName: fileName ?? this.fileName,
    size: size ?? this.size,
    lastAccess: lastAccess ?? this.lastAccess,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory ImageCacheVariant.fromMap(Map<String, dynamic> map) =>
      ImageCacheVariant._(
        id: map['rowid'] as int? ?? -1,
        photoId: map['photo_id'] as int,
        variant: map['variant'] as String,
        fileName: map['file_name'] as String,
        size: map['size'] as int,
        lastAccess: DateTime.fromMillisecondsSinceEpoch(
          map['last_access'] as int,
        ),
        createdDate: DateTime.fromMillisecondsSinceEpoch(
          map['created_date'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
        ),
        modifiedDate: DateTime.fromMillisecondsSinceEpoch(
          map['modified_date'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );

  @override
  Map<String, dynamic> toMap() => {
    'photo_id': photoId,
    'variant': variant,
    'file_name': fileName,
    'size': size,
    'last_access': lastAccess.millisecondsSinceEpoch,
    'created_date': createdDate.millisecondsSinceEpoch,
    'modified_date': modifiedDate.millisecondsSinceEpoch,
  };
}
