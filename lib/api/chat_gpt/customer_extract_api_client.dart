import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../dao/dao_system.dart';
import '../../util/dart/parse/parse_address.dart';
import '../../util/dart/parse/parse_customer.dart';

class CustomerExtractApiClient {
  Future<ParsedCustomer?> extract(String text) async {
    final system = await DaoSystem().get();
    final apiKey = system.openaiApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'Extract customer details from the message. Return JSON only '
                'with keys: customerName, firstName, surname, email, mobile, '
                'addressLine1, addressLine2, suburb, state, postcode. '
                'Use empty strings for unknown fields.',
          },
          {'role': 'user', 'content': text},
        ],
        'temperature': 0.1,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode}: ${response.body}',
      );
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    final choice =
        (jsonResponse['choices'] as List).first as Map<String, dynamic>;
    final rawContent =
        (choice['message'] as Map<String, dynamic>)['content'] as String;
    final content = _normalizeContent(rawContent);
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    final firstName = (parsed['firstName'] as String?)?.trim() ?? '';
    final surname = (parsed['surname'] as String?)?.trim() ?? '';
    final customerName =
        (parsed['customerName'] as String?)?.trim() ??
        [firstName, surname].where((p) => p.isNotEmpty).join(' ');

    final address = ParsedAddress(
      street: (parsed['addressLine1'] as String?)?.trim() ?? '',
      city: (parsed['suburb'] as String?)?.trim() ?? '',
      state: (parsed['state'] as String?)?.trim() ?? '',
      postalCode: (parsed['postcode'] as String?)?.trim() ?? '',
    );

    return ParsedCustomer(
      customerName: customerName,
      email: (parsed['email'] as String?)?.trim() ?? '',
      mobile: (parsed['mobile'] as String?)?.trim() ?? '',
      firstname: firstName,
      surname: surname,
      address: address,
    );
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
    trimmed = _stripWrappingQuotes(trimmed);
    return trimmed;
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
