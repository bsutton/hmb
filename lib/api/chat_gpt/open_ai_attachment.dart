import 'dart:typed_data';

class OpenAiAttachment {
  final String filename;
  final String mimeType;
  final Uint8List data;

  const OpenAiAttachment({
    required this.filename,
    required this.mimeType,
    required this.data,
  });
}

const int maxOpenAiAttachmentBytes = 10 * 1024 * 1024;
