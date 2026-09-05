/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A PDF output stream backed by a file rather than a growing [Uint8List].
class PdfFileOutput extends PdfStream {
  final RandomAccessFile _file;
  var _offset = 0;
  var _closed = false;

  PdfFileOutput._(this._file);

  factory PdfFileOutput.open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    return PdfFileOutput._(file.openSync(mode: FileMode.write));
  }

  @override
  int get offset => _offset;

  @override
  void putByte(int s) {
    _ensureOpen();
    _file.writeByteSync(s);
    _offset++;
  }

  @override
  void putBytes(List<int> s) {
    _ensureOpen();
    if (s.isEmpty) {
      return;
    }
    _file.writeFromSync(s);
    _offset += s.length;
  }

  @override
  void putStream(PdfStream s) {
    putBytes(s.output());
  }

  @override
  void setBytes(int offset, Iterable<int> iterable) {
    _ensureOpen();
    final current = _offset;
    _file
      ..setPositionSync(offset)
      ..writeFromSync(iterable is List<int> ? iterable : iterable.toList())
      ..setPositionSync(current);
  }

  @override
  Uint8List output() => throw UnsupportedError(
    'PdfFileOutput writes directly to disk and has no in-memory output',
  );

  void close() {
    if (_closed) {
      return;
    }
    _file
      ..flushSync()
      ..closeSync();
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PDF output is closed');
    }
  }
}

/// An image provider that embeds a cached JPEG directly from disk.
class PdfFileImage extends pw.ImageProvider {
  final String path;
  final int byteLength;

  factory PdfFileImage(String path) {
    final file = File(path);
    final length = file.lengthSync();
    final size = _readJpegSize(file, length);
    return PdfFileImage._(
      path: path,
      byteLength: length,
      width: size.width,
      height: size.height,
    );
  }

  PdfFileImage._({
    required this.path,
    required this.byteLength,
    required int width,
    required int height,
  }) : super(width, height, PdfImageOrientation.topLeft, null);

  @override
  PdfImage buildImage(pw.Context context, {int? width, int? height}) =>
      PdfImage.jpegStream(
        context.document,
        width: this.width!,
        height: this.height!,
        length: byteLength,
        write: _writeJpeg,
      );

  void _writeJpeg(PdfStream output) {
    final input = File(path).openSync();
    try {
      const chunkSize = 64 * 1024;
      while (true) {
        final chunk = input.readSync(chunkSize);
        if (chunk.isEmpty) {
          break;
        }
        output.putBytes(chunk);
      }
    } finally {
      input.closeSync();
    }
  }
}

Future<void> writePdfToFile(pw.Document document, String path) async {
  final output = PdfFileOutput.open(path);
  try {
    await document.write(output, enableEventLoopBalancing: true);
  } finally {
    output.close();
  }
}

({int width, int height}) _readJpegSize(File file, int fileLength) {
  final input = file.openSync();
  try {
    if (fileLength < 4 ||
        input.readByteSync() != 0xff ||
        input.readByteSync() != 0xd8) {
      throw FormatException('Not a JPEG: ${file.path}');
    }

    while (input.positionSync() < fileLength) {
      var prefix = input.readByteSync();
      while (prefix != 0xff && input.positionSync() < fileLength) {
        prefix = input.readByteSync();
      }

      var marker = input.readByteSync();
      while (marker == 0xff) {
        marker = input.readByteSync();
      }
      if (marker == 0xd9 || marker == 0xda) {
        break;
      }
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
        continue;
      }

      final segmentLength = _readUint16(input);
      if (segmentLength < 2) {
        throw FormatException('Invalid JPEG segment: ${file.path}');
      }
      if (_isStartOfFrame(marker)) {
        input.readByteSync();
        final height = _readUint16(input);
        final width = _readUint16(input);
        if (width <= 0 || height <= 0) {
          throw FormatException('Invalid JPEG dimensions: ${file.path}');
        }
        return (width: width, height: height);
      }

      input.setPositionSync(input.positionSync() + segmentLength - 2);
    }
  } finally {
    input.closeSync();
  }
  throw FormatException('JPEG dimensions not found: ${file.path}');
}

int _readUint16(RandomAccessFile input) =>
    (input.readByteSync() << 8) | input.readByteSync();

bool _isStartOfFrame(int marker) =>
    marker == 0xc0 ||
    marker == 0xc1 ||
    marker == 0xc2 ||
    marker == 0xc3 ||
    marker == 0xc5 ||
    marker == 0xc6 ||
    marker == 0xc7 ||
    marker == 0xc9 ||
    marker == 0xca ||
    marker == 0xcb ||
    marker == 0xcd ||
    marker == 0xce ||
    marker == 0xcf;
