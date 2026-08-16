import 'dart:convert';

import 'package:googleapis/gmail/v1.dart' as gmail;

import '../../database/management/backup_providers/google_drive/google_drive.g.dart';
import '../../ui/crud/job/job_creation_email_source.dart';
import '../../ui/dialog/google_mail_auth.dart';
import '../../util/dart/exceptions.dart';

class GmailMessageSummary {
  final String id;
  final String? threadId;
  final String sender;
  final String recipient;
  final String subject;
  final String snippet;
  final DateTime receivedAt;
  final bool hasAttachments;

  const GmailMessageSummary({
    required this.id,
    required this.threadId,
    required this.sender,
    required this.subject,
    required this.snippet,
    required this.receivedAt,
    required this.hasAttachments,
    this.recipient = '',
  });
}

class GmailSearchResult {
  final String accountEmail;
  final List<GmailMessageSummary> messages;
  final String? nextPageToken;

  const GmailSearchResult({
    required this.accountEmail,
    required this.messages,
    required this.nextPageToken,
  });
}

String buildGmailSearchQuery({
  String? text,
  bool unreadOnly = false,
  bool hasAttachments = false,
  int? newerThanDays = 30,
}) {
  final clauses = <String>[];
  // Gmail matches indexed tokens, not substrings. Text is deliberately
  // filtered locally so partial identifiers such as OC22 match OC22564.
  if (unreadOnly) {
    clauses.add('is:unread');
  }
  if (hasAttachments) {
    clauses.add('has:attachment');
  }
  if (newerThanDays != null) {
    clauses.add('newer_than:${newerThanDays}d');
  }
  return clauses.join(' ');
}

bool gmailMessageMatchesText(GmailMessageSummary message, String? textFilter) {
  final filter = textFilter?.trim().toLowerCase() ?? '';
  if (filter.isEmpty) {
    return true;
  }
  final sender = message.sender.toLowerCase();
  final recipient = message.recipient.toLowerCase();
  final subject = message.subject.toLowerCase();
  return sender.contains(filter) ||
      recipient.contains(filter) ||
      subject.contains(filter);
}

class GmailImportService {
  static const _summaryBatchSize = 4;
  static const _maximumMessagesScannedPerSearch = 300;
  final GoogleMailAuth _auth;
  GoogleAuthClient? _activeClient;
  var _cancelRequested = false;

  GmailImportService({GoogleMailAuth? auth}) : _auth = auth ?? GoogleMailAuth();

  Future<GmailSearchResult> search({
    String query = 'newer_than:30d',
    String? textFilter,
    String? pageToken,
    int maxResults = 30,
  }) async {
    _cancelRequested = false;
    GoogleAuthClient? client;
    try {
      final access = await _auth.getReadAccessToken();
      client = GoogleAuthClient({
        'Authorization': 'Bearer ${access.accessToken}',
        'X-Goog-AuthUser': '0',
      });
      _activeClient = client;
      final api = gmail.GmailApi(client);
      final profile = await api.users.getProfile('me');
      final messages = <GmailMessageSummary>[];
      var activePageToken = pageToken;
      String? nextPageToken;
      var scanned = 0;
      final hasTextFilter = (textFilter?.trim() ?? '').isNotEmpty;
      do {
        final response = await api.users.messages.list(
          'me',
          q: query.trim().isEmpty ? 'newer_than:30d' : query.trim(),
          pageToken: activePageToken,
          maxResults: maxResults,
        );
        final references = response.messages ?? const <gmail.Message>[];
        final summaries = await _loadSummaries(api, references);
        messages.addAll(_filterSummaries(summaries, textFilter));
        scanned += references.length;
        nextPageToken = response.nextPageToken;
        activePageToken = nextPageToken;
      } while (hasTextFilter &&
          messages.isEmpty &&
          nextPageToken != null &&
          scanned < _maximumMessagesScannedPerSearch);
      return GmailSearchResult(
        accountEmail: profile.emailAddress ?? access.email,
        messages: messages,
        nextPageToken: nextPageToken,
      );
    } on gmail.DetailedApiRequestError catch (error) {
      if (_cancelRequested) {
        throw const GmailImportCancelled();
      }
      throw _friendlyApiError(error);
    } catch (error) {
      if (_cancelRequested || error is GoogleMailAuthorizationCancelled) {
        throw const GmailImportCancelled();
      }
      rethrow;
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      client?.close();
    }
  }

  HMBException _friendlyApiError(gmail.DetailedApiRequestError error) {
    final message = error.message ?? '';
    if (error.status == 403 &&
        (message.contains('has not been used') ||
            message.contains('it is disabled'))) {
      return HMBException(
        'The Gmail API is disabled for the HMB Google Cloud project. Enable '
        'Gmail API for project 704526923643, wait a few minutes for Google '
        'to apply the change, then select Connect and search again. '
        'https://console.developers.google.com/apis/api/'
        'gmail.googleapis.com/overview?project=704526923643',
      );
    }
    if (error.status == 429 ||
        message.toLowerCase().contains('too many concurrent requests')) {
      return HMBException(
        'Gmail is temporarily limiting requests for this account. Wait a '
        'moment, then try loading the email again.',
      );
    }
    return HMBException('Gmail rejected the request: $message');
  }

  Future<void> cancelPendingOperation() async {
    _cancelRequested = true;
    await _auth.cancelPendingAuthorization();
    _activeClient?.close();
  }

  Future<JobCreationEmailSource> loadMessage({
    required String accountEmail,
    required String messageId,
  }) async {
    final access = await _auth.getReadAccessToken();
    final client = GoogleAuthClient({
      'Authorization': 'Bearer ${access.accessToken}',
      'X-Goog-AuthUser': '0',
    });
    try {
      final api = gmail.GmailApi(client);
      final profile = await api.users.getProfile('me');
      final message = await api.users.messages.get(
        'me',
        messageId,
        format: 'full',
      );
      return GmailMessageParser.parse(
        message,
        accountEmail:
            profile.emailAddress ??
            (access.email.isEmpty ? accountEmail : access.email),
      );
    } finally {
      client.close();
    }
  }

  Future<List<int>> loadAttachment({
    required String messageId,
    required JobCreationEmailAttachment attachment,
  }) async {
    final inlineData = attachment.inlineData;
    if (inlineData != null) {
      return _decodeBytes(inlineData);
    }
    final remoteId = attachment.remoteId;
    if (remoteId == null) {
      return const [];
    }

    final access = await _auth.getReadAccessToken();
    final client = GoogleAuthClient({
      'Authorization': 'Bearer ${access.accessToken}',
      'X-Goog-AuthUser': '0',
    });
    try {
      final api = gmail.GmailApi(client);
      final body = await api.users.messages.attachments.get(
        'me',
        messageId,
        remoteId,
      );
      return body.data == null ? const [] : _decodeBytes(body.data!);
    } finally {
      client.close();
    }
  }

  Future<GmailMessageSummary> _loadSummary(
    gmail.GmailApi api,
    gmail.Message message,
  ) async {
    late gmail.Message loaded;
    for (var attempt = 1; ; attempt++) {
      try {
        loaded = await api.users.messages.get(
          'me',
          message.id!,
          format: 'metadata',
          metadataHeaders: const ['From', 'To', 'Subject'],
        );
        break;
      } on gmail.DetailedApiRequestError catch (error) {
        if (error.status != 429 || attempt >= 3) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return GmailMessageSummary(
      id: loaded.id!,
      threadId: loaded.threadId,
      sender: GmailMessageParser.header(loaded, 'From'),
      recipient: GmailMessageParser.header(loaded, 'To'),
      subject: GmailMessageParser.header(loaded, 'Subject'),
      snippet: loaded.snippet ?? '',
      receivedAt: GmailMessageParser.receivedAt(loaded),
      hasAttachments: GmailMessageParser.hasAttachments(loaded.payload),
    );
  }

  Future<List<GmailMessageSummary>> _loadSummaries(
    gmail.GmailApi api,
    List<gmail.Message> references,
  ) async {
    final summaries = <GmailMessageSummary>[];
    for (
      var offset = 0;
      offset < references.length;
      offset += _summaryBatchSize
    ) {
      if (_cancelRequested) {
        throw const GmailImportCancelled();
      }
      final proposedEnd = offset + _summaryBatchSize;
      final end = proposedEnd < references.length
          ? proposedEnd
          : references.length;
      summaries.addAll(
        await Future.wait(
          references
              .sublist(offset, end)
              .map((message) => _loadSummary(api, message)),
        ),
      );
    }
    return summaries;
  }

  List<GmailMessageSummary> _filterSummaries(
    List<GmailMessageSummary> summaries,
    String? textFilter,
  ) => summaries
      .where((message) => gmailMessageMatchesText(message, textFilter))
      .toList();
}

class GmailImportCancelled implements Exception {
  const GmailImportCancelled();

  @override
  String toString() => 'Gmail import was cancelled.';
}

class GmailMessageParser {
  static JobCreationEmailSource parse(
    gmail.Message message, {
    required String accountEmail,
  }) {
    final from = header(message, 'From');
    final address = _parseAddress(from);
    return JobCreationEmailSource(
      accountEmail: accountEmail,
      messageId: message.id!,
      threadId: message.threadId,
      senderName: address.$1,
      senderEmail: address.$2,
      subject: header(message, 'Subject'),
      body: _bodyText(message.payload).trim(),
      receivedAt: receivedAt(message),
      hasAttachments: hasAttachments(message.payload),
      attachments: attachments(message.payload),
    );
  }

  static String header(gmail.Message message, String name) {
    for (final header
        in message.payload?.headers ?? const <gmail.MessagePartHeader>[]) {
      if (header.name?.toLowerCase() == name.toLowerCase()) {
        return header.value?.trim() ?? '';
      }
    }
    return '';
  }

  static DateTime receivedAt(gmail.Message message) {
    final millis = int.tryParse(message.internalDate ?? '');
    return millis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool hasAttachments(gmail.MessagePart? part) {
    if (part == null) {
      return false;
    }
    if ((part.filename ?? '').isNotEmpty || part.body?.attachmentId != null) {
      return true;
    }
    return (part.parts ?? const []).any(hasAttachments);
  }

  static List<JobCreationEmailAttachment> attachments(gmail.MessagePart? part) {
    final found = <JobCreationEmailAttachment>[];

    void visit(gmail.MessagePart? current) {
      if (current == null) {
        return;
      }
      final filename = current.filename ?? '';
      final remoteId = current.body?.attachmentId;
      final inlineData = current.body?.data;
      if (filename.isNotEmpty && (remoteId != null || inlineData != null)) {
        found.add(
          JobCreationEmailAttachment(
            key: remoteId ?? current.partId ?? filename,
            filename: filename,
            mimeType: current.mimeType ?? 'application/octet-stream',
            size: current.body?.size ?? 0,
            remoteId: remoteId,
            inlineData: inlineData,
          ),
        );
      }
      for (final child in current.parts ?? const <gmail.MessagePart>[]) {
        visit(child);
      }
    }

    visit(part);
    return found;
  }

  static String _bodyText(gmail.MessagePart? part) {
    if (part == null) {
      return '';
    }
    if (part.mimeType == 'text/plain' && part.body?.data != null) {
      return _decode(part.body!.data!);
    }
    for (final child in part.parts ?? const <gmail.MessagePart>[]) {
      final text = _bodyText(child);
      if (text.isNotEmpty) {
        return text;
      }
    }
    if (part.mimeType == 'text/html' && part.body?.data != null) {
      return _htmlToText(_decode(part.body!.data!));
    }
    return '';
  }

  static String _decode(String data) =>
      utf8.decode(_decodeBytes(data), allowMalformed: true);

  static String _htmlToText(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');

  static (String, String) _parseAddress(String from) {
    final match = RegExp(r'^\s*"?([^"<]*)"?\s*<([^>]+)>').firstMatch(from);
    if (match != null) {
      return ((match.group(1) ?? '').trim(), (match.group(2) ?? '').trim());
    }
    final email = RegExp(
      r'[\w.!#$%&\x27*+/=?^`{|}~-]+@[\w.-]+',
    ).firstMatch(from)?.group(0);
    return ('', email?.trim() ?? from.trim());
  }
}

List<int> _decodeBytes(String data) =>
    base64Url.decode(base64Url.normalize(data));
