import 'package:date_time_format/date_time_format.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../email_backup_provider.dart';

class LocalBackupProvider extends BackupProvider {
  @override
  Future<void> deleteBackup(Backup backupToDelete) {
    // TODO: implement deleteBackup
    throw UnimplementedError();
  }

  @override
  Future<Backup> getBackup(String pathTo) {
    // TODO: implement getBackup
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
        DateTimeFormat.format(DateTime.now(), format: 'Y.j.d.H.i.s');

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
}
