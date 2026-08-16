import 'dart:convert';

import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:hmb/integrations/gmail/gmail_import_service.dart';
import 'package:hmb/ui/crud/job/job_creation_email_source.dart';
import 'package:test/test.dart';

void main() {
  test('leaves text matching to the local contains filter', () {
    expect(buildGmailSearchQuery(text: 'Casey Customer'), 'newer_than:30d');
  });

  test('does not send punctuated partial text to Gmail', () {
    expect(buildGmailSearchQuery(text: 'Flutter-23'), 'newer_than:30d');
  });

  test('matches partial punctuated subjects locally', () {
    final message = GmailMessageSummary(
      id: 'message-23q',
      threadId: null,
      sender: 'noreply@example.com',
      recipient: 'owner@example.com',
      subject: 'FLUTTER-23Q - DetailedApiRequestError',
      snippet: '',
      receivedAt: DateTime.utc(2026, 8, 16),
      hasAttachments: false,
    );

    expect(gmailMessageMatchesText(message, 'Flutter-23'), isTrue);
    expect(gmailMessageMatchesText(message, '  '), isTrue);
    expect(gmailMessageMatchesText(message, 'unrelated'), isFalse);
  });

  test('combines text and advanced Gmail filters', () {
    expect(
      buildGmailSearchQuery(
        text: 'casey@example.com',
        unreadOnly: true,
        hasAttachments: true,
        newerThanDays: null,
      ),
      'is:unread has:attachment',
    );
  });

  test('parses Gmail headers, sender and plain text body', () {
    final message = gmail.Message(
      id: 'message-1',
      threadId: 'thread-1',
      internalDate: '1723593600000',
      payload: gmail.MessagePart(
        mimeType: 'multipart/mixed',
        headers: [
          gmail.MessagePartHeader(
            name: 'From',
            value: '"Casey Customer" <casey@example.com>',
          ),
          gmail.MessagePartHeader(name: 'Subject', value: 'Leaking tap'),
        ],
        parts: [
          gmail.MessagePart(
            mimeType: 'text/plain',
            body: gmail.MessagePartBody(data: _encode('Please fix my tap.')),
          ),
          gmail.MessagePart(
            mimeType: 'application/pdf',
            filename: 'photo.pdf',
            body: gmail.MessagePartBody(attachmentId: 'attachment-1'),
          ),
        ],
      ),
    );

    final source = GmailMessageParser.parse(
      message,
      accountEmail: 'owner@example.com',
    );

    expect(source.senderName, 'Casey Customer');
    expect(source.senderEmail, 'casey@example.com');
    expect(source.subject, 'Leaking tap');
    expect(source.body, 'Please fix my tap.');
    expect(source.hasAttachments, isTrue);
    expect(source.attachments, hasLength(1));
    expect(source.attachments.single.filename, 'photo.pdf');
    expect(source.aiText, contains('Subject: Leaking tap'));
  });

  test('uses an HTML body when plain text is unavailable', () {
    final message = gmail.Message(
      id: 'message-2',
      payload: gmail.MessagePart(
        mimeType: 'text/html',
        headers: [
          gmail.MessagePartHeader(name: 'From', value: 'casey@example.com'),
        ],
        body: gmail.MessagePartBody(
          data: _encode('<p>First line<br>Second &amp; third</p>'),
        ),
      ),
    );

    final source = GmailMessageParser.parse(
      message,
      accountEmail: 'owner@example.com',
    );

    expect(source.body, 'First line\nSecond & third');
  });

  test('loads inline attachment data without another API request', () async {
    final bytes = await GmailImportService().loadAttachment(
      messageId: 'message-3',
      attachment: JobCreationEmailAttachment(
        key: 'part-1',
        filename: 'photo.txt',
        mimeType: 'text/plain',
        size: 5,
        remoteId: null,
        inlineData: _encode('hello'),
      ),
    );

    expect(utf8.decode(bytes), 'hello');
  });
}

String _encode(String value) => base64UrlEncode(utf8.encode(value));
