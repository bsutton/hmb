/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, 
 with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for
    third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../dao/dao_system.dart';
import '../../util/dart/money_ex.dart';

class ReceiptExtractionResult {
  final DateTime? receiptDate;
  final String supplier;
  final int? jobNumber;
  final int totalExcludingTax;
  final int tax;
  final int totalIncludingTax;
  final List<ReceiptLineExtraction> lines;
  final List<String> warnings;

  const ReceiptExtractionResult({
    required this.receiptDate,
    required this.supplier,
    required this.jobNumber,
    required this.totalExcludingTax,
    required this.tax,
    required this.totalIncludingTax,
    required this.lines,
    required this.warnings,
  });
}

class ReceiptLineExtraction {
  final String description;
  final double quantity;
  final int unitPrice;
  final int lineTotalExTax;
  final int taxAmount;
  final int lineTotalIncTax;
  final int confidence;

  const ReceiptLineExtraction({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotalExTax,
    required this.taxAmount,
    required this.lineTotalIncTax,
    required this.confidence,
  });
}

class ReceiptApiClient {
  Future<ReceiptExtractionResult?> extractData(String filePath) async {
    final system = await DaoSystem().get();
    final apiKey = system.openaiApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final bytes = await File(filePath).readAsBytes();
    final b64 = base64Encode(bytes);
    final mimeType = _mimeType(filePath);

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
                'You extract supplier receipt data for a handyman accounting '
                'app. Return JSON only. Money values must be integer minor '
                'units in the receipt currency, e.g. cents. Use generic tax '
                'terminology; do not assume GST. Return keys: receipt_date '
                '(YYYY-MM-DD or empty), job_number (integer or null), supplier '
                '(string), total_excluding_tax, tax, total_including_tax, '
                'warnings (array of strings), lines (array). Each line must '
                'have description, quantity, unit_price, line_total_ex_tax, '
                'tax_amount, line_total_inc_tax, confidence (0-100). If a '
                'field is unreadable use 0 or empty string and add a warning.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Extract receipt header totals and line items.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$b64'},
              },
            ],
          },
        ],
        'temperature': 0.0,
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
    return _parse(_normalizeContent(rawContent));
  }

  ReceiptExtractionResult _parse(String content) {
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final rawDate = (parsed['receipt_date'] as String? ?? '').trim();
    final lines = (parsed['lines'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (line) => ReceiptLineExtraction(
            description: (line['description'] as String? ?? '').trim(),
            quantity: (line['quantity'] as num?)?.toDouble() ?? 1,
            unitPrice: _minorUnits(line['unit_price']),
            lineTotalExTax: _minorUnits(line['line_total_ex_tax']),
            taxAmount: _minorUnits(line['tax_amount']),
            lineTotalIncTax: _minorUnits(line['line_total_inc_tax']),
            confidence: (line['confidence'] as num?)?.round() ?? 0,
          ),
        )
        .where((line) => line.description.isNotEmpty)
        .toList();

    return ReceiptExtractionResult(
      receiptDate: rawDate.isEmpty ? null : DateTime.tryParse(rawDate),
      supplier: (parsed['supplier'] as String? ?? '').trim(),
      jobNumber: (parsed['job_number'] as num?)?.round(),
      totalExcludingTax: _minorUnits(parsed['total_excluding_tax']),
      tax: _minorUnits(parsed['tax']),
      totalIncludingTax: _minorUnits(parsed['total_including_tax']),
      lines: lines,
      warnings: (parsed['warnings'] as List<dynamic>? ?? const [])
          .map((warning) => warning.toString())
          .where((warning) => warning.trim().isNotEmpty)
          .toList(),
    );
  }

  int _minorUnits(Object? value) {
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return MoneyEx.tryParse(value).minorUnits.toInt();
    }
    return 0;
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
    return trimmed;
  }

  String _mimeType(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    return switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
