import 'entity.dart';

class JobSourceEmail extends Entity<JobSourceEmail> {
  int jobId;
  String accountEmail;
  String messageId;
  String? threadId;
  String senderEmail;
  String subject;
  DateTime receivedAt;

  JobSourceEmail._({
    required super.id,
    required this.jobId,
    required this.accountEmail,
    required this.messageId,
    required this.threadId,
    required this.senderEmail,
    required this.subject,
    required this.receivedAt,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  JobSourceEmail.forInsert({
    required this.jobId,
    required this.accountEmail,
    required this.messageId,
    required this.threadId,
    required this.senderEmail,
    required this.subject,
    required this.receivedAt,
  }) : super.forInsert();

  factory JobSourceEmail.fromMap(Map<String, dynamic> map) => JobSourceEmail._(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    accountEmail: map['account_email'] as String,
    messageId: map['message_id'] as String,
    threadId: map['thread_id'] as String?,
    senderEmail: map['sender_email'] as String,
    subject: map['subject'] as String,
    receivedAt: DateTime.parse(map['received_at'] as String),
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'account_email': accountEmail,
    'message_id': messageId,
    'thread_id': threadId,
    'sender_email': senderEmail,
    'subject': subject,
    'received_at': receivedAt.toUtc().toIso8601String(),
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
