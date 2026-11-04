@Tags(['flutter'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/factory/flutter_database_factory.dart';
import 'package:hmb/database/management/backup_providers/google_drive/background_backup/google_drive_backup_provider.dart';
import 'package:hmb/util/dart/exceptions.dart';
import 'package:path/path.dart';

void main() {
  test(
    'oversized Drive backup download stops and removes the partial file',
    () async {
      final root = await Directory.systemTemp.createTemp('hmb-drive-bound-');
      try {
        final destination = join(root.path, 'download.zip');
        final provider = GoogleDriveBackupProvider(FlutterDatabaseFactory());
        await expectLater(
          provider.saveStreamToFile(
            Stream.fromIterable([List.filled(8, 1), List.filled(8, 2)]),
            destination,
            maxBytes: 10,
          ),
          throwsA(isA<BackupException>()),
        );
        expect(File(destination).existsSync(), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
