class JobCreationEmailSource {
  final String accountEmail;
  final String messageId;
  final String? threadId;
  final String senderName;
  final String senderEmail;
  final String subject;
  final String body;
  final DateTime receivedAt;
  final bool hasAttachments;
  final List<JobCreationEmailAttachment> attachments;

  const JobCreationEmailSource({
    required this.accountEmail,
    required this.messageId,
    required this.threadId,
    required this.senderName,
    required this.senderEmail,
    required this.subject,
    required this.body,
    required this.receivedAt,
    required this.hasAttachments,
    this.attachments = const [],
  });

  String get aiText {
    final sender = senderName.isEmpty
        ? senderEmail
        : '$senderName <$senderEmail>';
    return [
      if (sender.isNotEmpty) 'From: $sender',
      if (subject.isNotEmpty) 'Subject: $subject',
      '',
      body,
    ].join('\n').trim();
  }
}

class JobCreationEmailAttachment {
  final String key;
  final String filename;
  final String mimeType;
  final int size;
  final String? remoteId;
  final String? inlineData;

  const JobCreationEmailAttachment({
    required this.key,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.remoteId,
    required this.inlineData,
  });
}
