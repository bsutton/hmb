/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/entity/quote_line_group.dart

import 'entity.dart';

enum LineApprovalStatus { preApproval, approved, rejected }

class QuoteLineGroup extends Entity<QuoteLineGroup> {
  QuoteLineGroup({
    required super.id,
    required this.quoteId,
    required this.taskId,
    required this.name,
    required this.assumption,
    required super.createdDate,
    required super.modifiedDate,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super();

  QuoteLineGroup.forInsert({
    required this.quoteId,
    required this.taskId,
    required this.name,
    required this.assumption,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super.forInsert();

  QuoteLineGroup.forUpdate({
    required super.entity,
    required this.quoteId,
    required this.taskId,
    required this.name,
    required this.assumption,
    this.lineApprovalStatus = LineApprovalStatus.preApproval,
  }) : super.forUpdate();

  factory QuoteLineGroup.fromMap(Map<String, dynamic> map) => QuoteLineGroup(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    taskId: map['task_id'] as int?,
    name: map['name'] as String,
    assumption: map['assumption'] as String,
    lineApprovalStatus: LineApprovalStatus.values.byName(
      map['line_approval_status'] as String,
    ),

    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  int quoteId;
  int? taskId;
  String name;
  String assumption;
  LineApprovalStatus lineApprovalStatus;

  QuoteLineGroup copyWith({
    int? id,
    int? quoteId,
    int? taskId,
    String? name,
    String? assumption,
    LineApprovalStatus? lineApprovalStatus,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) => QuoteLineGroup(
    id: id ?? this.id,
    quoteId: quoteId ?? this.quoteId,
    taskId: taskId ?? this.taskId,
    name: name ?? this.name,
    assumption: assumption ?? this.assumption,
    lineApprovalStatus: lineApprovalStatus ?? this.lineApprovalStatus,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'task_id': taskId,
    'name': name,
    'assumption': assumption,
    'line_approval_status': lineApprovalStatus.name,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
