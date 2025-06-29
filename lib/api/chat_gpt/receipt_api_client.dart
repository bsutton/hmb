/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/api/receipt_api_client.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'chat_gpt_auth_service.dart';

class ReceiptApiClient {
  final _auth = ChatGptAuth();

  /// Uploads a receipt image and extracts data via OpenAI ChatGPT API,
  /// using ChatGptAuth for token management.
  Future<Map<String, dynamic>> extractData(String filePath) async {
    // Ensure user is authenticated and get a valid token
    final token = await _auth.getAccessToken();

    // Read & encode image
    final bytes = await File(filePath).readAsBytes();
    final b64 = base64Encode(bytes);

    // Call OpenAI
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content':
                'Extract the following fields from the base64-encoded receipt image: receipt_date (YYYY-MM-DD), job/order number (if present), supplier (if present), total_excluding_tax (in cents), tax (in cents), total_including_tax (in cents). Respond with a JSON object only.',
          },
          {'role': 'user', 'content': b64},
        ],
        'temperature': 0.0,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode}: ${response.body}',
      );
    }

    final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
    final choice =
        (jsonResponse['choices'] as List).first as Map<String, dynamic>;
    final content =
        (choice['message'] as Map<String, dynamic>)['content'] as String;
    return json.decode(content) as Map<String, dynamic>;
  }
}
