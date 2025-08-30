/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'entity.dart';

enum ParentType { task, tool, receipt }

class Photo extends Entity<Photo> {
  int parentId;
  ParentType parentType;

  /// Stores the file name (sans path) within the photo cache.
  String filename;

  String comment;

  /// Backup location path
  /// The [pathToCloudStorage] is set once we upload the photo.
  String? pathToCloudStorage;

  /// Backup path structure version
  /// The [pathVersion] is set once we upload the photo.
  int? pathVersion;

  /// The last time the photo was backed up.
  /// Normally we would only ever backup a photo once.
  DateTime? lastBackupDate;

  Photo({
    required super.id,
    required this.parentId,
    required this.parentType,
    required this.filename,
    required this.comment,
    required this.lastBackupDate,
    required super.createdDate,
    required super.modifiedDate,
    this.pathToCloudStorage,
    this.pathVersion,
  }) : super();

  Photo.forInsert({
    required this.parentId,
    required this.parentType,
    required this.filename,
    required this.comment,
    this.pathToCloudStorage,
    this.pathVersion = 1,
    this.lastBackupDate,
  }) : super.forInsert();

  Photo.forUpdate({
    required super.entity,
    required this.parentId,
    required this.parentType,
    required this.filename,
    required this.comment,
    this.pathToCloudStorage,
    this.pathVersion,
    this.lastBackupDate,
  }) : super.forUpdate();

  factory Photo.fromMap(Map<String, dynamic> map) => Photo(
    id: map['id'] as int,
    parentId: map['parentId'] as int,
    parentType: ParentType.values.byName(map['parentType'] as String),
    filename: map['filename'] as String, // <- renamed column
    comment: map['comment'] as String,
    lastBackupDate: map['last_backup_date'] == null
        ? null
        : DateTime.parse(map['last_backup_date'] as String),
    pathToCloudStorage: map['path_to_cloud_storage'] as String?,
    pathVersion: map['path_version'] as int?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'parentId': parentId,
    'parentType': parentType.name,
    'filename': filename, // <- renamed column
    'comment': comment,
    'last_backup_date': lastBackupDate?.toIso8601String(),
    'path_to_cloud_storage': pathToCloudStorage,
    'path_version': pathVersion,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
