/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hmb/ui/pdf/pdf_file_output.dart';
import 'package:image/image.dart' as image;
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'hmb_pdf_file_output_test_',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  group('PdfFileOutput', () {
    test('writes bytes directly and tracks offsets', () {
      final path = '${temporaryDirectory.path}/bytes.bin';
      final output = PdfFileOutput.open(path)
        ..putByte(1)
        ..putBytes(const <int>[2, 3])
        ..putString('ab');

      expect(output.offset, 5);
      output.close();

      expect(
        File(path).readAsBytesSync(),
        orderedEquals(<int>[1, 2, 3, 97, 98]),
      );
    });

    test('supports patches without moving the output offset', () {
      final path = '${temporaryDirectory.path}/patched.bin';
      final output = PdfFileOutput.open(path)
        ..putBytes(const <int>[1, 2, 3, 4])
        ..setBytes(1, const <int>[8, 9]);

      expect(output.offset, 4);
      output.close();
      expect(File(path).readAsBytesSync(), orderedEquals(<int>[1, 8, 9, 4]));
    });

    test('close is idempotent and further writes fail', () {
      final output = PdfFileOutput.open('${temporaryDirectory.path}/closed.bin')
        ..close()
        ..close();
      expect(() => output.putByte(1), throwsStateError);
      expect(output.output, throwsUnsupportedError);
    });
  });

  group('PDF file serialization', () {
    test('writes a valid PDF envelope without an in-memory save', () async {
      final path = '${temporaryDirectory.path}/document.pdf';
      final document = pw.Document()
        ..addPage(pw.Page(build: (_) => pw.Text('streamed to disk')));

      await writePdfToFile(document, path);

      final text = latin1.decode(File(path).readAsBytesSync());
      expect(text, startsWith('%PDF-1.5'));
      expect(text, contains('startxref\n'));
      expect(text, endsWith('%%EOF\n'));
    });

    test('embeds cached JPEG bytes from their file path', () async {
      final jpeg = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 13, height: 9), quality: 70),
      );
      final jpegPath = '${temporaryDirectory.path}/photo.jpg';
      File(jpegPath).writeAsBytesSync(jpeg);
      final provider = PdfFileImage(jpegPath);
      final pdfPath = '${temporaryDirectory.path}/with_image.pdf';
      final document = pw.Document()
        ..addPage(
          pw.Page(build: (_) => pw.Image(provider, width: 100, height: 100)),
        );

      expect(provider.width, 13);
      expect(provider.height, 9);
      await writePdfToFile(document, pdfPath);

      final pdfBytes = File(pdfPath).readAsBytesSync();
      expect(_indexOf(pdfBytes, jpeg), greaterThanOrEqualTo(0));
    });

    test(
      'can post-process and stream a document in a worker isolate',
      () async {
        final jpeg = Uint8List.fromList(
          image.encodeJpg(image.Image(width: 17, height: 10), quality: 70),
        );
        final jpegPath = '${temporaryDirectory.path}/worker_photo.jpg';
        File(jpegPath).writeAsBytesSync(jpeg);
        final pdfPath = '${temporaryDirectory.path}/worker.pdf';
        final document = pw.Document()
          ..addPage(pw.Page(build: (_) => pw.Image(PdfFileImage(jpegPath))));

        await Isolate.run(() => writePdfToFile(document, pdfPath));

        final pdfBytes = File(pdfPath).readAsBytesSync();
        expect(latin1.decode(pdfBytes), endsWith('%%EOF\n'));
        expect(_indexOf(pdfBytes, jpeg), greaterThanOrEqualTo(0));
      },
    );

    test('reads portrait JPEG dimensions', () {
      final jpegPath = '${temporaryDirectory.path}/portrait.jpg';
      File(
        jpegPath,
      ).writeAsBytesSync(image.encodeJpg(image.Image(width: 5, height: 11)));

      final provider = PdfFileImage(jpegPath);

      expect(provider.width, 5);
      expect(provider.height, 11);
    });

    test('rejects non-JPEG input before document generation', () {
      final path = '${temporaryDirectory.path}/not_an_image.jpg';
      File(path).writeAsStringSync('not a JPEG');

      expect(() => PdfFileImage(path), throwsFormatException);
    });

    test('propagates a missing source file', () {
      expect(
        () => PdfFileImage('${temporaryDirectory.path}/missing.jpg'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

int _indexOf(Uint8List haystack, Uint8List needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return i;
    }
  }
  return -1;
}
