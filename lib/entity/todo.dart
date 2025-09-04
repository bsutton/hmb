/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
 with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for
     third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'entity.dart';

enum ToDoStatus { open, done }

enum ToDoPriority { none, low, medium, high }

enum ToDoParentType { job, customer }

class ToDo extends Entity<ToDo> {
  final String title;
  final String? note;

  /// Optional due-by date/time.
  final DateTime? dueDate;

  /// Optional reminder time (for local notifications).
  final DateTime? remindAt;

  final ToDoPriority priority;
  final ToDoStatus status;

  /// Optional linkage to Job/Customer (or null for personal).
  final ToDoParentType? parentType;
  final int? parentId;

  /// Set when status becomes `done`.
  final DateTime? completedDate;

  ToDo({
    required super.id,
    required this.title,
    required this.status,
    required this.priority,
    required super.createdDate,
    required super.modifiedDate,
    this.note,
    this.dueDate,
    this.remindAt,
    this.parentType,
    this.parentId,
    this.completedDate,
  });

  ToDo.forInsert({
    required this.title,
    this.note,
    this.dueDate,
    this.remindAt,
    this.priority = ToDoPriority.none,
    this.status = ToDoStatus.open,
    this.parentType,
    this.parentId,
  }) : completedDate = null,
       super.forInsert();

  ToDo copyWith({
    String? title,
    String? note,
    DateTime? dueDate,
    DateTime? remindAt,
    ToDoPriority? priority,
    ToDoStatus? status,
    ToDoParentType? parentType,
    int? parentId,
    DateTime? completedDate,
  }) => ToDo(
    id: id,
    title: title ?? this.title,
    note: note ?? this.note,
    dueDate: dueDate ?? this.dueDate,
    remindAt: remindAt ?? this.remindAt,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    parentType: parentType ?? this.parentType,
    parentId: parentId ?? this.parentId,
    completedDate: completedDate ?? this.completedDate,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory ToDo.fromMap(Map<String, dynamic> map) => ToDo(
    id: map['id'] as int,
    title: map['title'] as String,
    note: map['note'] as String?,
    dueDate: (map['due_date'] as String?) != null
        ? DateTime.parse(map['due_date'] as String)
        : null,
    remindAt: (map['remind_at'] as String?) != null
        ? DateTime.parse(map['remind_at'] as String)
        : null,
    priority: ToDoPriority.values.firstWhere(
      (e) => e.name == (map['priority'] as String),
    ),
    status: ToDoStatus.values.firstWhere(
      (e) => e.name == (map['status'] as String),
    ),
    parentType: (map['parent_type'] as String?) != null
        ? ToDoParentType.values.firstWhere(
            (e) => e.name == (map['parent_type'] as String),
          )
        : null,
    parentId: map['parent_id'] as int?,
    completedDate: (map['completed_date'] as String?) != null
        ? DateTime.parse(map['completed_date'] as String)
        : null,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'note': note,
    'due_date': dueDate?.toIso8601String(),
    'remind_at': remindAt?.toIso8601String(),
    'priority': priority.name,
    'status': status.name,
    'parent_type': parentType?.name,
    'parent_id': parentId,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
    'completed_date': completedDate?.toIso8601String(),
  };
}
