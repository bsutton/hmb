import '../../../../dao/dao_photo.dart';
import '../../../../database/factory/flutter_database_factory.dart';
import '../../../../database/management/backup_providers/google_drive/background_backup/google_drive_backup_provider.dart';
import '../../../../database/management/backup_providers/google_drive/google_drive.g.dart';

class BackupReminderStatus {
  final bool needsReminder;
  final bool dbBackupOverdue;
  final bool photoSyncPending;

  const BackupReminderStatus({
    required this.needsReminder,
    required this.dbBackupOverdue,
    required this.photoSyncPending,
  });
}

class BackupReminder {
  static Future<BackupReminderStatus> getStatus() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final lastBackup = await _getLastGoogleDriveBackup();
    final dbBackupOverdue = lastBackup == null || lastBackup.isBefore(cutoff);
    final photoSyncPending = (await DaoPhoto().countUnsyncedPhotos()) > 0;

    return BackupReminderStatus(
      needsReminder: dbBackupOverdue || photoSyncPending,
      dbBackupOverdue: dbBackupOverdue,
      photoSyncPending: photoSyncPending,
    );
  }

  static Future<DateTime?> _getLastGoogleDriveBackup() async {
    try {
      if (!GoogleDriveApi.isSupported()) {
        return null;
      }

      final auth = await GoogleDriveAuth.instance();
      await auth.signInIfAutomatic();
      if (!auth.isSignedIn) {
        return null;
      }

      final backups = await GoogleDriveBackupProvider(
        FlutterDatabaseFactory(),
      ).getBackups();
      if (backups.isEmpty) {
        return null;
      }
      DateTime? latest;
      for (final backup in backups) {
        if (latest == null || backup.when.isAfter(latest)) {
          latest = backup.when;
        }
      }
      return latest;
    } catch (_) {
      return null;
    }
  }
}
