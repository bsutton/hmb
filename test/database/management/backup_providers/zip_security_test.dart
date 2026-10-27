@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/flutter_database_factory.dart';
import 'package:hmb/database/management/backup_providers/zip_isolate.dart';
import 'package:path/path.dart';

import 'test_backup_provider.dart';

void main() {
  test('current database-only backup restores to staging', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-normal-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('database')));
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(root.path, 'app.db'),
        photosDirectory: documents.path,
      );

      expect(
        await extractFiles(provider, backup, staging.path, 1, 1),
        join(staging.path, 'handyman.db'),
      );
      expect(
        File(join(staging.path, 'handyman.db')).readAsStringSync(),
        'database',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('malicious backup entries cannot write outside restore roots', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-security-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final photos = Directory(join(root.path, 'data', 'photos'))
        ..createSync(recursive: true);
      final outsideDatabase = File(join(root.path, 'outside.db'));
      final outsidePhoto = File(join(root.path, 'outside.txt'));
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('../outside.db', utf8.encode('database')));
      final backup = File(join(root.path, 'malicious.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(root.path, 'database.db'),
        photosDirectory: photos.path,
      );

      await expectLater(
        extractFiles(provider, backup, staging.path, 1, 1),
        throwsA(isA<FormatException>()),
      );
      expect(outsideDatabase.existsSync(), isFalse);
      expect(outsidePhoto.existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'photo entries cannot write to the Documents or live database',
    () async {
      final root = await Directory.systemTemp.createTemp('hmb-zip-documents-');
      try {
        final documents = Directory(join(root.path, 'documents'))..createSync();
        final staging = Directory(join(root.path, 'staging'))..createSync();
        final liveDatabase = File(join(documents.path, 'handyman.db'))
          ..writeAsStringSync('original');
        final document = File(join(documents.path, 'contract.pdf'))
          ..writeAsStringSync('original');
        final archive = Archive()
          ..addFile(ArchiveFile.bytes('photos/handyman.db', utf8.encode('bad')))
          ..addFile(
            ArchiveFile.bytes('photos/contract.pdf', utf8.encode('bad')),
          );
        final backup = File(join(root.path, 'backup.zip'))
          ..writeAsBytesSync(ZipEncoder().encode(archive));
        final provider = TestBackupProvider(
          FlutterDatabaseFactory(),
          liveDatabase.path,
          photosDirectory: documents.path,
        );

        await expectLater(
          extractFiles(provider, backup, staging.path, 1, 1),
          throwsA(isA<FormatException>()),
        );
        expect(liveDatabase.readAsStringSync(), 'original');
        expect(document.readAsStringSync(), 'original');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('an invalid later entry prevents an earlier database write', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-preflight-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('database')))
        ..addFile(ArchiveFile.bytes('photos/../../evil', utf8.encode('bad')));
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      await expectLater(
        extractFiles(provider, backup, staging.path, 1, 1),
        throwsA(isA<FormatException>()),
      );
      expect(File(join(staging.path, 'handyman.db')).existsSync(), isFalse);
      expect(File(join(root.path, 'evil')).existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('database destination cannot be an existing symlink', () async {
    if (Platform.isWindows) {
      return;
    }
    final root = await Directory.systemTemp.createTemp('hmb-zip-link-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final photos = Directory(join(root.path, 'photos'))..createSync();
      final outside = Directory(join(root.path, 'outside'))..createSync();
      Link(
        join(staging.path, 'handyman.db'),
      ).createSync(join(outside.path, 'escaped.db'));
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('marker')));
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(root.path, 'app.db'),
        photosDirectory: photos.path,
      );

      await expectLater(
        extractFiles(provider, backup, staging.path, 1, 1),
        throwsA(isA<FormatException>()),
      );
      expect(File(join(outside.path, 'escaped.db')).existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('compressed backup cannot expand beyond the configured bound', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-bomb-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', List.filled(128 * 1024, 0)));
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      await expectLater(
        extractFiles(
          provider,
          backup,
          staging.path,
          1,
          1,
          maxDatabaseBytes: 64 * 1024,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(File(join(staging.path, 'handyman.db')).existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('understated ZIP size still stops decompression at the bound', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-size-lie-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', List.filled(128 * 1024, 0)));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final directoryOffset = _signature(bytes, 0x02014b50);
      ByteData.sublistView(
        bytes,
      ).setUint32(directoryOffset + 24, 32 * 1024, Endian.little);
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(bytes);
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      await expectLater(
        extractFiles(
          provider,
          backup,
          staging.path,
          1,
          1,
          maxDatabaseBytes: 64 * 1024,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(File(join(staging.path, 'handyman.db')).existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('Unix symlink metadata is rejected before decoder expansion', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-symlink-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('db')))
        ..addFile(
          ArchiveFile.bytes('ignored.txt', List.filled(128 * 1024, 65)),
        );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final directoryOffset = _signature(bytes, 0x02014b50);
      final second = _signature(bytes, 0x02014b50, from: directoryOffset + 4);
      ByteData.sublistView(bytes)
        ..setUint16(second + 4, 0x0314, Endian.little)
        ..setUint32(second + 38, 0xa000 << 16, Endian.little);
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(bytes);
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      await expectLater(
        extractFiles(provider, backup, staging.path, 1, 1),
        throwsA(isA<FormatException>()),
      );
      expect(File(join(staging.path, 'handyman.db')).existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('duplicate central-directory records count before decoding', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-duplicates-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('db')));
      final original = Uint8List.fromList(ZipEncoder().encode(archive));
      final centralStart = _signature(original, 0x02014b50);
      final end = _signature(original, 0x06054b50);
      final central = original.sublist(centralStart, end);
      final bytes = Uint8List.fromList([
        ...original.sublist(0, centralStart),
        for (var i = 0; i < 1025; i++) ...central,
        ...original.sublist(end),
      ]);
      final newEnd = centralStart + 1025 * central.length;
      ByteData.sublistView(bytes)
        ..setUint16(newEnd + 8, 1025, Endian.little)
        ..setUint16(newEnd + 10, 1025, Endian.little)
        ..setUint32(newEnd + 12, 1025 * central.length, Endian.little);
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(bytes);
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      await expectLater(
        extractFiles(provider, backup, staging.path, 1, 1),
        throwsA(isA<FormatException>()),
      );
      expect(File(join(staging.path, 'handyman.db')).existsSync(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('EOCD-shaped data in a comment cannot redirect extraction', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-comment-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('database')));
      final original = Uint8List.fromList(ZipEncoder().encode(archive));
      final end = _signature(original, 0x06054b50);
      final falseEnd = Uint8List(22);
      ByteData.sublistView(falseEnd).setUint32(0, 0x06054b50, Endian.little);
      final bytes = Uint8List.fromList([...original, ...falseEnd, 65]);
      ByteData.sublistView(bytes).setUint16(end + 20, 23, Endian.little);
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(bytes);
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      expect(
        await extractFiles(provider, backup, staging.path, 1, 1),
        join(staging.path, 'handyman.db'),
      );
      expect(
        File(join(staging.path, 'handyman.db')).readAsStringSync(),
        'database',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('ZIP64 locator cannot redirect extraction metadata', () async {
    final root = await Directory.systemTemp.createTemp('hmb-zip-zip64-');
    try {
      final staging = Directory(join(root.path, 'staging'))..createSync();
      final documents = Directory(join(root.path, 'documents'))..createSync();
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('database')));
      final original = Uint8List.fromList(ZipEncoder().encode(archive));
      final end = _signature(original, 0x06054b50);
      final locator = Uint8List(20);
      ByteData.sublistView(locator).setUint32(0, 0x07064b50, Endian.little);
      final bytes = Uint8List.fromList([
        ...original.sublist(0, end),
        ...locator,
        ...original.sublist(end),
      ]);
      final backup = File(join(root.path, 'backup.zip'))
        ..writeAsBytesSync(bytes);
      final provider = TestBackupProvider(
        FlutterDatabaseFactory(),
        join(documents.path, 'handyman.db'),
        photosDirectory: documents.path,
      );
      expect(
        await extractFiles(provider, backup, staging.path, 1, 1),
        join(staging.path, 'handyman.db'),
      );
      expect(
        File(join(staging.path, 'handyman.db')).readAsStringSync(),
        'database',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'local compression method cannot differ from central metadata',
    () async {
      final root = await Directory.systemTemp.createTemp('hmb-zip-method-');
      try {
        final staging = Directory(join(root.path, 'staging'))..createSync();
        final documents = Directory(join(root.path, 'documents'))..createSync();
        final archive = Archive()
          ..addFile(ArchiveFile.bytes('handyman.db', utf8.encode('database')));
        final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
        // ZIP local header method is at offset 8; central record stays deflate.
        ByteData.sublistView(bytes).setUint16(8, 0, Endian.little);
        final backup = File(join(root.path, 'backup.zip'))
          ..writeAsBytesSync(bytes);
        final provider = TestBackupProvider(
          FlutterDatabaseFactory(),
          join(documents.path, 'handyman.db'),
          photosDirectory: documents.path,
        );
        await expectLater(
          extractFiles(provider, backup, staging.path, 1, 1),
          throwsA(isA<FormatException>()),
        );
        expect(File(join(staging.path, 'handyman.db')).existsSync(), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}

int _signature(Uint8List bytes, int signature, {int from = 0}) {
  final data = ByteData.sublistView(bytes);
  for (var offset = from; offset <= bytes.length - 4; offset++) {
    if (data.getUint32(offset, Endian.little) == signature) {
      return offset;
    }
  }
  throw StateError('ZIP signature not found: $signature');
}
