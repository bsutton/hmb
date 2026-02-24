import '../../../../dao/dao_photo.dart';
import '../../../../database/management/backup_providers/backup_history_store.dart';

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
    final lastBackup = await BackupHistoryStore.latestSuccessfulBackup();
    final dbBackupOverdue = lastBackup == null || lastBackup.isBefore(cutoff);
    final photoSyncPending = (await DaoPhoto().countUnsyncedPhotos()) > 0;

    return BackupReminderStatus(
      needsReminder: dbBackupOverdue || photoSyncPending,
      dbBackupOverdue: dbBackupOverdue,
      photoSyncPending: photoSyncPending,
    );
  }
}
