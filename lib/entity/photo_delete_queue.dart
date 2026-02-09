/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 GPL terms per repo license.
*/

import 'entity.dart';

/// Represents a photo queued for remote deletion.
class PhotoDeleteQueue extends Entity<PhotoDeleteQueue> {
  final int photoId;

  PhotoDeleteQueue._({
    required super.id,
    required this.photoId,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  PhotoDeleteQueue.forInsert({required this.photoId}) : super.forInsert();

  PhotoDeleteQueue copyWith({int? id, int? photoId}) => PhotoDeleteQueue._(
    id: id ?? this.id,
    photoId: photoId ?? this.photoId,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory PhotoDeleteQueue.fromMap(Map<String, dynamic> map) =>
      PhotoDeleteQueue._(
        id: map['id'] as int,
        photoId: map['photo_id'] as int,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'photo_id': photoId,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}
