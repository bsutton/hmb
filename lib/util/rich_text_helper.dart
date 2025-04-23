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
