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

class Version extends Entity<Version> {
  final int dbVersion;
  final String codeVersion;

  Version({
    required super.id,
    required this.dbVersion,
    required this.codeVersion,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Version.forInsert({required this.dbVersion, required this.codeVersion})
    : super.forInsert();

  Version.forUpdate({
    required super.entity,
    required this.dbVersion,
    required this.codeVersion,
  }) : super.forUpdate();

  factory Version.fromMap(Map<String, dynamic> map) => Version(
    id: map['id'] as int,
    dbVersion: map['db_version'] as int,
    codeVersion: map['code_version'] as String,
    createdDate:
        DateTime.tryParse(map['created_date'] as String? ?? '') ??
        DateTime.now(),
    modifiedDate:
        DateTime.tryParse(map['modified_date'] as String? ?? '') ??
        DateTime.now(),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'db_version': dbVersion,
    'code_version': codeVersion,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
