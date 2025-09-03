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

enum CheckListType {
  owned, // owned by an entity such as task
  global, // not attached to any entity
  defaultList,

  /// Used to populate new checklists from a default set of items
}

class CheckList extends Entity<CheckList> {
  String name;
  String description;
  CheckListType listType;

  CheckList({
    required super.id,
    required this.name,
    required this.description,
    required this.listType,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  CheckList.forInsert({
    required this.name,
    required this.description,
    required this.listType,
  }) : super.forInsert();

  CheckList copyWith({
    String? name,
    String? description,
    CheckListType? listType,
  }) => CheckList(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    listType: listType ?? this.listType,
    createdDate: createdDate,
    modifiedDate: DateTime.now(),
  );

  factory CheckList.fromMap(Map<String, dynamic> map) => CheckList(
    id: map['id'] as int,
    name: map['name'] as String,
    description: map['description'] as String,
    listType: CheckListType.values[(map['list_type'] as int) - 1],
    createdDate: DateTime.parse(map['createdDate'] as String),
    modifiedDate: DateTime.parse(map['modifiedDate'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'list_type': listType.index + 1,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
  };
}
