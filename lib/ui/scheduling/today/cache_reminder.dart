import '../../../dao/dao_image_cache_variant.dart';
import '../../../dao/dao_photo.dart';
import '../../../dao/dao_system.dart';

class CacheReminderStatus {
  final bool needsReminder;
  final bool cacheLimitExceeded;
  final bool photoSyncPending;

  const CacheReminderStatus({
    required this.needsReminder,
    required this.cacheLimitExceeded,
    required this.photoSyncPending,
  });
}

class CacheReminder {
  static Future<CacheReminderStatus> getStatus() async {
    final system = await DaoSystem().get();
    final maxBytes = system.photoCacheMaxMb * 1024 * 1024;
    final totalBytes = await DaoImageCacheVariant().totalBytes();
    final photoSyncPending = (await DaoPhoto().countUnsyncedPhotos()) > 0;
    final cacheLimitExceeded = totalBytes > maxBytes;

    return CacheReminderStatus(
      needsReminder: cacheLimitExceeded && photoSyncPending,
      cacheLimitExceeded: cacheLimitExceeded,
      photoSyncPending: photoSyncPending,
    );
  }
}
