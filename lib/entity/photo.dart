import 'entity.dart';

class Photo extends Entity<Photo> {
  Photo({
    required super.id,
    required this.taskId,
    required this.filePath,
    required this.comment,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Photo.forInsert({
    required this.taskId,
    required this.filePath,
    required this.comment,
  }) : super.forInsert();

  Photo.forUpdate({
    required super.entity,
    required this.taskId,
    required this.filePath,
    required this.comment,
  }) : super.forUpdate();

  factory Photo.fromMap(Map<String, dynamic> map) => Photo(
        id: map['id'] as int,
        taskId: map['taskId'] as int,
        filePath: map['filePath'] as String,
        comment: map['comment'] as String,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  int taskId;
  String filePath;
  String comment;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'filePath': filePath,
        'comment': comment,
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };
}
