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
import 'package:path/path.dart';

import '../backup.dart';
import '../backup_provider.dart';

class DevBackupProvider extends BackupProvider {
  DevBackupProvider(super.databaseFactory);

  @override
  String get name => 'Dev Backup';

  @override
  Future<void> deleteBackup(Backup backupToDelete) async {
    delete(backupToDelete.pathTo);
  }

  @override
  Future<File> fetchBackup(Backup backup) async => File(backup.pathTo);

  @override
  Future<List<Backup>> getBackups() async {
    final paths = find('*.zip', workingDirectory: _pathToBackups()).toList();

    return paths
        .map(
          (filePath) => Backup(
            id: 'not used',
            when: stat(filePath).modified,
            size: '${stat(filePath).size}',
            status: 'good',
            pathTo: filePath,
            error: 'none',
          ),
        )
        .toList();
  }

  String _pathToBackups() =>
      join(DartProject.self.pathToProjectRoot, 'backups');

  @override
  Future<BackupResult> store({
    required String pathToDatabaseCopy,
    required String pathToZippedBackup,
    required int version,
  }) async {
    final basePath = join(
      DartProject.self.pathToProjectRoot,
      'backups',
      basenameWithoutExtension(pathToZippedBackup),
    );
    final ext = extension(pathToZippedBackup);

    var count = 0;
    String pathToBackupFile;
    do {
      pathToBackupFile =
          count == 0 ? '$basePath$ext' : '$basePath.$count$ext';
      count++;
    } while (exists(pathToBackupFile));
    print('Saving backup to $pathToBackupFile');
    move(pathToZippedBackup, pathToBackupFile);

    return BackupResult(
      pathToBackup: pathToBackupFile,
      pathToSource: await databasePath,
      success: true,
    );
  }

  @override
  Future<String> get photosRootPath async =>
      join(DartProject.self.pathToProjectRoot, 'photos');

  @override
  Future<String> get backupLocation async => _pathToBackups();

  @override
  Future<void> syncPhotos() {
    throw UnimplementedError();
  }
}
