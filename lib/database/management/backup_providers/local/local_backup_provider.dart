import 'dart:io';

import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqflite.dart';

import '../../../../util/log.dart';
import '../../../../util/paths.dart'
    if (dart.library.ui) '../../../../util/paths_flutter.dart';
import '../backup_provider.dart';

/// Does on device backups.
class LocalBackupProvider extends BackupProvider {
  LocalBackupProvider(super.databaseFactory);

  @override
  String get name => 'Local Backup';

  @override
  Future<void> deleteBackup(Backup backupToDelete) async {
    delete(backupToDelete.pathTo);
  }

  @override
  Future<File> fetchBackup(Backup backup) async =>
      File(backup.pathTo);

  @override
  Future<List<Backup>> getBackups() async {
    final backups = <String>[];
    final backupPath = await _pathToBackupDir;
    Log.d('Searching for backups in $backupPath');
    find('*.zip', workingDirectory: backupPath, progress: (item) {
      backups.add(item.pathTo);
      return true;
    });

    return backups
        .map((filePath) => Backup(
            id: 'not used',
            when: stat(filePath).modified,
            size: '${stat(filePath).size}',
            status: 'good',
            pathTo: filePath,
            error: 'none'))
        .toList();
  }

  @override
  Future<BackupResult> store(
      {required String pathToDatabaseCopy,
      required String pathToZippedBackup,
      required int version}) async {
    final datePart =
        DateTimeFormat.format(DateTime.now(), format: 'Y-j-d-H-i-s-');

    final pathToBackupDir = await _pathToBackupDir;

    if (!exists(pathToBackupDir)) {
      createDir(pathToBackupDir, recursive: true);
    }

    /// db file path with .bak and date/time/added
    final pathToBackupFile = '$pathToBackupDir.$version.$datePart.zip';

    move(pathToZippedBackup, pathToBackupFile);

    return BackupResult(
        pathToBackup: pathToBackupFile,
        pathToSource: await databasePath,
        success: true);
  }

  @override
  Future<String> get backupLocation async => _pathToBackupDir;

  Future<String> get _pathToBackupDir async =>
      join((await getApplicationDocumentsDirectory()).path, 'hmb', 'backups');

  @override
  Future<String> get photosRootPath => getPhotosRootPath();

  @override
  Future<String> get databasePath async =>
      join(await getDatabasesPath(), 'handyman.db');
}
