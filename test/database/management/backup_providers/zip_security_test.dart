@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:io';

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
}
