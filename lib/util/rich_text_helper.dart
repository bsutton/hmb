/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:fleather/fleather.dart';

import '../ui/widgets/media/rich_editor.dart';

class RichTextHelper {
  static String toPlainText(String richText) =>
      parchmentToPlainText(RichEditor.createParchment(richText));

  static String parchmentToPlainText(ParchmentDocument document) {
    final text = document.toPlainText().replaceAll('\n\n', '\n');
    // Remove any trailing newline characters
    return text.replaceAll(RegExp(r'\n+$'), '');
  }
}
