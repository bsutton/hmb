import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

import '../../../factory/hmb_database_factory.dart';
import '../backup_provider.dart';

class DevBackupProvider extends BackupProvider {
  DevBackupProvider(super.databaseFactory);

  @override
  Future<void> deleteBackup(Backup backupToDelete) {
    // TODO(bsutton): implement deleteBackup
    throw UnimplementedError();
  }

  @override
  Future<Backup> getBackup(String pathTo) {
    // TODO(bsutton): implement getBackup
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getBackups() {
    // TODO(bsutton): implement getBackups
    throw UnimplementedError();
  }

  @override
  Future<void> restoreDatabase(String pathToRestoreDatabase,
      BackupProvider backupProvider, HMBDatabaseFactory databaseFactory) {
    // TODO(bsutton): implement restoreDatabase
    throw UnimplementedError();
  }

  @override
  Future<BackupResult> store(
      {required String pathToDatabase,
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
        pathToSource: pathToZippedBackup,
        success: true);
  }
}
