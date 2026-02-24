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

class QuoteTaskPhoto extends Entity<QuoteTaskPhoto> {
  int quoteId;
  int taskId;
  int photoId;
  int displayOrder;
  String comment;

  QuoteTaskPhoto._({
    required super.id,
    required this.quoteId,
    required this.taskId,
    required this.photoId,
    required this.displayOrder,
    required this.comment,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  QuoteTaskPhoto.forInsert({
    required this.quoteId,
    required this.taskId,
    required this.photoId,
    required this.displayOrder,
    this.comment = '',
  }) : super.forInsert();

  factory QuoteTaskPhoto.fromMap(Map<String, dynamic> map) => QuoteTaskPhoto._(
    id: map['id'] as int,
    quoteId: map['quote_id'] as int,
    taskId: map['task_id'] as int,
    photoId: map['photo_id'] as int,
    displayOrder: map['display_order'] as int? ?? 0,
    comment: map['comment'] as String? ?? '',
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'quote_id': quoteId,
    'task_id': taskId,
    'photo_id': photoId,
    'display_order': displayOrder,
    'comment': comment,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
