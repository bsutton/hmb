import 'entity.dart';

class Version extends Entity<Version> {
  Version({
    required super.id,
    required this.dbVersion,
    required this.codeVersion,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  Version.forInsert({
    required this.dbVersion,
    required this.codeVersion,
  }) : super.forInsert();

  Version.forUpdate({
    required super.entity,
    required this.dbVersion,
    required this.codeVersion,
  }) : super.forUpdate();

  factory Version.fromMap(Map<String, dynamic> map) => Version(
        id: map['id'] as int,
        dbVersion: map['db_version'] as int,
        codeVersion: map['code_version'] as String,
        createdDate: DateTime.tryParse(map['created_date'] as String? ?? '') ??
            DateTime.now(),
        modifiedDate:
            DateTime.tryParse(map['modified_date'] as String? ?? '') ??
                DateTime.now(),
      );

  final int dbVersion;
  final String codeVersion;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'db_version': dbVersion,
        'code_version': codeVersion,
        'created_date': createdDate.toIso8601String(),
        'modified_date': modifiedDate.toIso8601String(),
      };
}
