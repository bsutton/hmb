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

class Category extends Entity<Category> {
  Category({
    required super.id,
    required this.name,
    required super.createdDate,
    required super.modifiedDate,
    this.description,
  });

  Category.forInsert({required this.name, this.description})
    : super.forInsert();

  Category.forUpdate({
    required Category entity,
    required this.name,
    this.description,
  }) : super.forUpdate(entity: entity);

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int,
    name: map['name'] as String,
    description: map['description'] as String?,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  final String name;
  final String? description;

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
