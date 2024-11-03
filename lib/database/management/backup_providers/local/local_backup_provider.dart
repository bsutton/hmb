import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../../factory/hmb_database_factory.dart';
import '../backup_provider.dart';

class LocalBackupProvider extends BackupProvider {
  LocalBackupProvider(super.databaseFactory);

  @override
  Future<void> deleteBackup(Backup backupToDelete) {
    throw UnimplementedError();
  }

  @override
  Future<Backup> getBackup(String pathTo) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getBackups() async {
    final backups = <String>[];
    find('*.zip', workingDirectory: await _pathToBackupDir, progress: (item) {
      backups.add(item.pathTo);
      return true;
    });

    return backups;
  }

  @override
  Future<BackupResult> store(
      {required String pathToDatabase,
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
        pathToSource: pathToZippedBackup,
        success: true);
  }

  Future<String> get _pathToBackupDir async =>
      join((await getApplicationDocumentsDirectory()).path, 'hmb', 'backups');

  @override
  Future<void> restoreDatabase(String pathToRestoreDatabase,
      BackupProvider backupProvider, HMBDatabaseFactory databaseFactory) async {
    // TODO(bsutton): implement restoreDatabase
    throw UnimplementedError();
  }
}
