/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:convert';

class RichTextHelper {
  static String toPlainText(String richText) =>
      parchmentJsonToPlainText(richText);

  static String parchmentJsonToPlainText(String richText) {
    if (richText.trim().isEmpty) {
      return '';
    }

    final ops = _extractOps(richText);
    if (ops == null) {
      return _cleanupPlainText(richText);
    }

    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is! Map) {
        continue;
      }
      final insert = op['insert'];
      if (insert is String) {
        buffer.write(insert);
      } else if (insert is Map) {
        // Preserve line breaks for embeds without pulling in rich-text deps.
        buffer.write('\n');
      }
    }

    return _cleanupPlainText(buffer.toString());
  }

  static List<dynamic>? _extractOps(String richText) {
    try {
      final decoded = jsonDecode(richText);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      if (decoded is Map && decoded['ops'] is List<dynamic>) {
        return decoded['ops'] as List<dynamic>;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static String _cleanupPlainText(String text) {
    final normalised = text.replaceAll('\r\n', '\n');
    final collapsed = normalised.replaceAll(RegExp(r'\n{2,}'), '\n');
    // Remove any trailing newline characters
    return collapsed.replaceAll(RegExp(r'\n+$'), '');
  }
}
