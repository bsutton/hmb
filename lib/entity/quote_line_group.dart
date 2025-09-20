// lib/entity/quote_line_group.dart

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

enum LineApprovalStatus { preApproval, approved, rejected }

class QuoteLineGroup extends Entity<QuoteLineGroup> {
  int quoteId;
  int? taskId;
  // from the task name.
  String name;
  // from the task description
  String description;
  // from the task assumptions
  String assumption;
  LineApprovalStatus lineApprovalStatus;

  QuoteLineGroup._({
    required super.id,
    required this.quoteId,
    required this.taskId,
    required this.name,
    required this.description,
    required this.assumption,
    required super.createdDate,
    required super.modifiedDate,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super();

  QuoteLineGroup.forInsert({
    required this.quoteId,
    required this.taskId,
    required this.name,
    this.description = '',
    this.assumption = '',
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super.forInsert();

  QuoteLineGroup copyWith({
    int? quoteId,
    int? taskId,
    String? name,
    String? assumption,
    String? description,
    LineApprovalStatus? lineApprovalStatus,
  }) => QuoteLineGroup._(
    id: id,
    quoteId: quoteId ?? this.quoteId,
    taskId: taskId ?? this.taskId,
    name: name ?? this.name,
    assumption: assumption ?? this.assumption,
    description: description ?? this.description,
    lineApprovalStatus: lineApprovalStatus ?? this.lineApprovalStatus,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory QuoteLineGroup.fromMap(Map<String, dynamic> map) => QuoteLineGroup._(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    taskId: map['task_id'] as int?,
    name: map['name'] as String,
    assumption: map['assumption'] as String? ?? '',
    description: map['description'] as String? ?? '',
    lineApprovalStatus: LineApprovalStatus.values.byName(
      map['line_approval_status'] as String,
    ),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'task_id': taskId,
    'name': name,
    'assumption': assumption,
    'description': description,
    'line_approval_status': lineApprovalStatus.name,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
