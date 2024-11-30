import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

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
        .map((filePath) => Backup(
            id: 'not used',
            when: stat(filePath).modified,
            size: '${stat(filePath).size}',
            status: 'good',
            pathTo: filePath,
            error: 'none'))
        .toList();
  }

  String _pathToBackups() =>
      join(DartProject.self.pathToProjectRoot, 'backups');

  @override
  Future<BackupResult> store(
      {required String pathToDatabaseCopy,
      required String pathToZippedBackup,
      required int version}) async {
    var pathToBackupFile = join(DartProject.self.pathToProjectRoot, 'backups',
        basename(pathToZippedBackup));

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
        success: true);
  }

  @override
  Future<String> get photosRootPath async =>
      join(DartProject.self.pathToProjectRoot, 'photos');

  @override
  Future<String> get databasePath async => join(
      DartProject.self.pathToProjectRoot,
      '.dart_tool',
      'sqflite_common_ffi',
      'databases',
      'handyman.db');

  @override
  Future<String> get backupLocation async => _pathToBackups();
}
