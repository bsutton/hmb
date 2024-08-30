import 'entity.dart';

enum MessageTemplateOwner { user, system }

enum MessageType {
  sms,
  email,
}

class MessageTemplate extends Entity<MessageTemplate> {
  MessageTemplate({
    required super.id,
    required this.title,
    required this.message,
    required this.messageType,
    required this.owner,
    required this.enabled,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  MessageTemplate.forInsert({
    required this.title,
    required this.message,
    required this.messageType,
    this.owner =
        MessageTemplateOwner.user, // User templates are created by default
    this.enabled = true,
  }) : super.forInsert();

  MessageTemplate.forUpdate({
    required super.entity,
    required this.title,
    required this.message,
    required this.messageType,
    required this.owner,
    required this.enabled,
  }) : super.forUpdate();

  factory MessageTemplate.fromMap(Map<String, dynamic> map) => MessageTemplate(
        id: map['id'] as int,
        title: map['title'] as String,
        message: map['message'] as String,
        messageType: MessageType.values.byName(map['message_type'] as String),
        owner: MessageTemplateOwner.values[map['owner'] as int],
        enabled: map['enabled'] as int == 1,
        createdDate: DateTime.parse(map['createdDate'] as String),
        modifiedDate: DateTime.parse(map['modifiedDate'] as String),
      );

  String title;
  String message;
  MessageType messageType; // Indicates whether the template is for SMS or email
  MessageTemplateOwner owner; // Identifies if it's a user or system template
  bool enabled; // Indicates if the template is enabled

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'message_type': messageType.name, // Store the enum as a string
        'owner': owner.index,
        'enabled': enabled ? 1 : 0,
        'createdDate': createdDate.toIso8601String(),
        'modifiedDate': modifiedDate.toIso8601String(),
      };
}
