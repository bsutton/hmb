import 'entity.dart';

class TaskCheckList extends Entity<TaskCheckList> {
  TaskCheckList({
    required super.id,
    required this.taskId,
    required this.checkListId,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  TaskCheckList.forInsert({required this.taskId, required this.checkListId})
    : super.forInsert();

  TaskCheckList.forUpdate({
    required super.entity,
    required this.taskId,
    required this.checkListId,
  }) : super.forUpdate();

  factory TaskCheckList.fromMap(Map<String, dynamic> map) => TaskCheckList(
    id: map['id'] as int,
    taskId: map['task_id'] as int,
    checkListId: map['check_list_id'] as int,
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  int taskId;
  int checkListId;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'check_list_id': checkListId,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}
