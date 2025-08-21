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
