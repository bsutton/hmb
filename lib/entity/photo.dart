import '../dao/dao_photo.dart';
import 'entity.dart';

class Photo extends Entity<Photo> {
  Photo({
    required super.id,
    required this.parentId,
    required this.parentType,
    required this.filePath,
    required this.comment,
    required this.lastBackupDate,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Photo.forInsert({
    required this.parentId,
    required this.parentType,
    required this.filePath,
    required this.comment,
    this.lastBackupDate,
  }) : super.forInsert();

  Photo.forUpdate({
    required super.entity,
    required this.parentId,
    required this.parentType,
    required this.filePath,
    required this.comment,
    this.lastBackupDate,
  }) : super.forUpdate();

  factory Photo.fromMap(Map<String, dynamic> map) => Photo(
        id: map['id'] as int,
        parentId: map['parentId'] as int,
        parentType: ParentType.values.byName(map['parentType'] as String),
        filePath: map['filePath'] as String,
        comment: map['comment'] as String,
        lastBackupDate: map['last_backup_date'] == null
            ? null
            : DateTime.parse(map['last_backup_date'] as String),
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  int parentId;
  ParentType parentType;
  String filePath;
  String comment;

  /// The last time the photo was backed up.
  /// Normally we would only ever back a photo once.
  DateTime? lastBackupDate;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'parentId': parentId,
        'parentType': parentType.name,
        'filePath': filePath,
        'comment': comment,
        'last_backup_date': lastBackupDate?.toIso8601String(),
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };
}


