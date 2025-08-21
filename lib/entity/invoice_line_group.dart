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

/// Allows us to group invoice lines together.
/// Currently used to group all lines related to a specific task.
class InvoiceLineGroup extends Entity<InvoiceLineGroup> {
  int invoiceId;
  String name;

  InvoiceLineGroup({
    required super.id,
    required this.invoiceId,
    required this.name,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  InvoiceLineGroup.forInsert({required this.invoiceId, required this.name})
    : super.forInsert();

  InvoiceLineGroup.forUpdate({
    required super.entity,
    required this.invoiceId,
    required this.name,
  }) : super.forUpdate();

  factory InvoiceLineGroup.fromMap(Map<String, dynamic> map) =>
      InvoiceLineGroup(
        id: map['id'] as int,
        invoiceId: map['invoice_id'] as int,
        name: map['name'] as String,
        createdDate: DateTime.parse(map['created_date'] as String),
        modifiedDate: DateTime.parse(map['modified_date'] as String),
      );

  InvoiceLineGroup copyWith({
    int? id,
    int? invoiceId,
    String? name,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) => InvoiceLineGroup(
    id: id ?? this.id,
    invoiceId: invoiceId ?? this.invoiceId,
    name: name ?? this.name,
    createdDate: createdDate ?? this.createdDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'invoice_id': invoiceId,
    'name': name,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
