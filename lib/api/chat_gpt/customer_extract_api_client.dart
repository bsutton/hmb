import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../dao/dao_system.dart';
import '../../util/dart/parse/parse_address.dart';
import '../../util/dart/parse/parse_customer.dart';

class CustomerExtractAttachment {
  final String filename;
  final String mimeType;
  final Uint8List data;

  const CustomerExtractAttachment({
    required this.filename,
    required this.mimeType,
    required this.data,
  });
}

class CustomerExtractApiClient {
  static const int maxAttachmentBytes = 10 * 1024 * 1024;

  Future<ParsedCustomer?> extract(
    String text, {
    List<CustomerExtractAttachment> attachments = const [],
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
    List<CustomerExtractAttachment> attachments,
  ) {
    final content = <Map<String, dynamic>>[
      {'type': 'input_text', 'text': text},
      ...attachments
          .where((attachment) => attachment.data.length <= maxAttachmentBytes)
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

  static const _systemPrompt =
      'Extract customer details from the message and any attached documents. '
      'Return JSON only with keys: customerName, companyName, firstName, '
      'surname, email, mobile, addressLine1, addressLine2, suburb, state, '
      'postcode. If a company is clearly associated with the customer, set '
      'companyName and prefer customerName to be the company name. Use empty '
      'strings for unknown fields.';

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
