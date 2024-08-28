import 'entity.dart';

enum SmsTemplateType { user, system }

class SmsTemplate extends Entity<SmsTemplate> {
  SmsTemplate({
    required super.id,
    required this.title,
    required this.message,
    required this.type,
    required this.enabled,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  SmsTemplate.forInsert({
    required this.title,
    required this.message,
    this.type = SmsTemplateType.user, // User templates are created by default
    this.enabled = true,
  }) : super.forInsert();

  SmsTemplate.forUpdate({
    required super.entity,
    required this.title,
    required this.message,
    required this.type,
    required this.enabled,
  }) : super.forUpdate();

  factory SmsTemplate.fromMap(Map<String, dynamic> map) => SmsTemplate(
        id: map['id'] as int,
        title: map['title'] as String,
        message: map['message'] as String,
        type: SmsTemplateType.values[map['type'] as int],
        enabled: map['enabled'] as int == 1,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  String title;
  String message;
  SmsTemplateType type; // Identifies if it's a user or system template
  bool enabled; // Indicates if the template is enabled

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.index,
        'enabled': enabled ? 1 : 0,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };
}
