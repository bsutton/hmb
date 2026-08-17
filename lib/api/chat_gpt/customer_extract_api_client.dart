import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../dao/dao_system.dart';
import '../../util/dart/parse/parse_address.dart';
import '../../util/dart/parse/parse_customer.dart';
import 'open_ai_attachment.dart';

class CustomerExtractApiClient {
  Future<ParsedCustomer?> extract(
    String text, {
    List<OpenAiAttachment> attachments = const [],
  }) async {
    final credentials = await DaoSystem().getOpenAiCredentials();
    final apiKey = credentials.apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final response = attachments.isEmpty
        ? await _textRequest(apiKey, text)
        : await _fileRequest(apiKey, text, attachments);

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode}: ${response.body}',
      );
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    final rawContent = attachments.isEmpty
        ? _chatContent(jsonResponse)
        : _responseContent(jsonResponse);
    final content = _normalizeContent(rawContent);
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    final firstName = (parsed['firstName'] as String?)?.trim() ?? '';
    final surname = (parsed['surname'] as String?)?.trim() ?? '';
    final companyName = (parsed['companyName'] as String?)?.trim() ?? '';
    final customerNameRaw = (parsed['customerName'] as String?)?.trim() ?? '';
    final personName = [
      firstName,
      surname,
    ].where((p) => p.isNotEmpty).join(' ');
    final customerName = companyName.isNotEmpty
        ? companyName
        : (customerNameRaw.isNotEmpty ? customerNameRaw : personName);

    final address = ParsedAddress(
      street: (parsed['addressLine1'] as String?)?.trim() ?? '',
      city: (parsed['suburb'] as String?)?.trim() ?? '',
      state: (parsed['state'] as String?)?.trim() ?? '',
      postalCode: (parsed['postcode'] as String?)?.trim() ?? '',
    );

    return ParsedCustomer(
      customerName: customerName,
      companyName: companyName,
      email: (parsed['email'] as String?)?.trim() ?? '',
      mobile: (parsed['mobile'] as String?)?.trim() ?? '',
      firstname: firstName,
      surname: surname,
      address: address,
    );
  }

  Future<http.Response> _textRequest(String apiKey, String text) => http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      'model': 'gpt-4o-mini',
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': text},
      ],
      'temperature': 0.1,
    }),
  );

  Future<http.Response> _fileRequest(
    String apiKey,
    String text,
    List<OpenAiAttachment> attachments,
  ) {
    final content = <Map<String, dynamic>>[
      {'type': 'input_text', 'text': text},
      ...attachments
          .where(
            (attachment) => attachment.data.length <= maxOpenAiAttachmentBytes,
          )
          .map(
            (attachment) => {
              'type': 'input_file',
              'filename': attachment.filename,
              'file_data':
                  'data:${attachment.mimeType};base64,'
                  '${base64Encode(attachment.data)}',
            },
          ),
    ];
    return http.post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'input': [
          {
            'role': 'system',
            'content': [
              {'type': 'input_text', 'text': _systemPrompt},
            ],
          },
          {'role': 'user', 'content': content},
        ],
        'text': {
          'format': {'type': 'json_object'},
        },
        'temperature': 0.1,
      }),
    );
  }

  static const _systemPrompt = '''
Extract the party and contact details for a handyman job from the email and
attached documents. Return JSON only with keys: customerName, companyName,
firstName, surname, email, mobile, addressLine1, addressLine2, suburb, state,
postcode.

Interpret work orders as follows:
- The addressee or named contractor is the handyman receiving the job, not the
  customer. Never return the contractor's details as the customer.
- firstName, surname, email and mobile belong to the person explicitly named
  as the contact for questions or correspondence. Ignore unmonitored and
  do-not-reply addresses when another contact is supplied.
- The address fields are the work-site or service address. Do not use the
  property manager's office, postal or invoice address when a work site is
  present.
- companyName is the organisation that ordered or manages the work.
- customerName is the owners corporation, property owner, tenant or other
  principal receiving the work. If no distinct principal is named, use the
  organisation or contact person's full name.
- Prefer explicit details in an attached work order over email signatures.
- Do not invent missing values. Use empty strings for unknown fields.
''';

  String _chatContent(Map<String, dynamic> response) {
    final choice = (response['choices'] as List).first as Map<String, dynamic>;
    return (choice['message'] as Map<String, dynamic>)['content'] as String;
  }

  String _responseContent(Map<String, dynamic> response) {
    final output = response['output'] as List<dynamic>? ?? const [];
    for (final item in output) {
      final content =
          (item as Map<String, dynamic>)['content'] as List<dynamic>?;
      for (final part in content ?? const []) {
        final text = (part as Map<String, dynamic>)['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text;
        }
      }
    }
    throw const FormatException('OpenAI returned no extraction content.');
  }

  String _normalizeContent(String content) {
    var trimmed = content.trim();
    if (trimmed.startsWith('```')) {
      final lines = trimmed.split('\n').toList();
      if (lines.isNotEmpty && lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
        lines.removeLast();
      }
      trimmed = lines.join('\n').trim();
    }
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        trimmed = jsonDecode(trimmed) as String;
      } catch (_) {
        // fall through and try to parse as-is
      }
    }
    return _stripWrappingQuotes(trimmed);
  }

  String _stripWrappingQuotes(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    String stripPair(String input, String quote) {
      var out = input;
      while (out.startsWith(quote) && out.endsWith(quote) && out.length >= 2) {
        out = out.substring(quote.length, out.length - quote.length).trim();
      }
      return out;
    }

    trimmed = stripPair(trimmed, '"');
    trimmed = stripPair(trimmed, "'");
    return trimmed;
  }
}
