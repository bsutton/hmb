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

import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:hmb/database/management/backup_providers/backup.dart';
import 'package:hmb/database/management/backup_providers/backup_provider.dart';
import 'package:path/path.dart';

class TestBackupProvider extends BackupProvider {
  String pathToDatabase;

  TestBackupProvider(super.databaseFactory, this.pathToDatabase);

  @override
  String get name => 'Test Backup';

  @override
  Future<void> deleteBackup(Backup backupToDelete) {
    throw UnimplementedError();
  }

  @override
  Future<File> fetchBackup(Backup backup) {
    throw UnimplementedError();
  }

  @override
  Future<List<Backup>> getBackups() {
    throw UnimplementedError();
  }

  @override
  Future<BackupResult> store({
    required String pathToDatabaseCopy,
    required String pathToZippedBackup,
    required int version,
  }) async {
    var pathToBackupFile = join(
      DartProject.self.pathToProjectRoot,
      'backups',
      basename(pathToZippedBackup),
    );

    var count = 1;
    while (exists(pathToBackupFile)) {
      pathToBackupFile =
          '''${join(dirname(pathToBackupFile), basenameWithoutExtension(pathToBackupFile))}.${count++}${extension(pathToBackupFile)}''';
    }
    print('Saving backup to $pathToBackupFile');
    move(pathToZippedBackup, pathToBackupFile);

    return BackupResult(
      pathToBackup: pathToBackupFile,
      pathToSource: await databasePath,
      success: true,
    );
  }

  @override
  Future<String> get backupLocation async => 'None';

  @override
  Future<String> get photosRootPath async =>
      join(DartProject.self.pathToProjectRoot, 'photos');

  @override
  Future<String> get databasePath async => pathToDatabase;

  @override
  Future<void> syncPhotos() {
    throw UnimplementedError();
  }
}
