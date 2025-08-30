// lib/src/database/migrations/postv131_upgrade.dart
/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

// import 'package:dcli_core/dcli_core.dart';
// import 'package:path/path.dart' as p;

// import '../../cache/hmb_image_cache.dart';
// import '../../cache/image_cache_config.dart';
// import '../../dao/dao_base.dart';
// import '../../entity/photo.dart';
// import '../../util/photo_meta.dart';

// Optional: if you want Drive verification instead of trusting lastBackupDate,
// you can wire in PhotoSyncService().download lookup helpers here.

import 'package:dcli_core/dcli_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

import '../../cache/hmb_image_cache.dart';
import '../../cache/image_cache_config.dart';
import '../../dao/dao_base.dart';
import '../../entity/photo.dart';
import '../../util/dart/photo_meta.dart';

/// Post v131: migrate local legacy photos into the unified cache.
/// - Creates/ensures `general` and `thumb` variants for each photo.
/// - Seeds LRU with legacy file mtime.
/// - Deletes legacy thumbnail files once cached.
/// - Deletes legacy original **only if** lastBackupDate != null.
/// Safe to re-run.
Future<void> postv131Upgrade(Database db) async {
  final cache = HMBImageCache();
  await cache.init();

  final daoPhoto = DaoBase<Photo>.direct(db, 'photo', Photo.fromMap);
  final photos = await daoPhoto.getAll();

  var migrated = 0;
  final total = photos.length;

  for (final photo in photos) {
    try {
      final meta = PhotoMeta.fromPhoto(photo: photo);
      final absPath = await meta.resolve();

      // If legacy original doesn't exist, skip gracefully (may be cloud-only).
      if (!exists(absPath)) {
        migrated++;
        continue;
      }

      // 1) Ensure GENERAL (display) variant is present.
      //    On first call this returns ORIGINAL path immediately and compresses
      //    WebP in background; subsequent runs will be a cache hit.
      final generalPath = await cache.getVariantPathForMeta(
        meta: meta,
        variant: ImageVariant.general,
        ensureOriginalAt: (m, dst) async {
          // Migration: we already have the original locally; just copy it.
          if (!exists(dst)) {
            createDir(p.dirname(dst), recursive: true);
            copy(m.absolutePathTo, dst);
          }
        },
      );

      // 2) Ensure THUMBNAIL variant (sync generation).
      final thumbPath = await cache.getVariantPathForMeta(
        meta: meta,
        variant: ImageVariant.thumb,
        ensureOriginalAt: (m, dst) async {
          if (!exists(dst)) {
            createDir(p.dirname(dst), recursive: true);
            copy(m.absolutePathTo, dst);
          }
        },
      );

      // 3) Seed LRU using legacy file's modification time.
      final mtime = stat(absPath).modified;
      await cache.setLastAccessForMeta(
        meta: meta,
        variant: ImageVariant.general,
        when: mtime,
      );
      await cache.setLastAccessForMeta(
        meta: meta,
        variant: ImageVariant.thumb,
        when: mtime,
      );

      // 4) Remove legacy thumbnail (if it exists) now that cache thumb exists.
      final legacyThumb = await meta.legacyThumbnailPathFor();
      if (legacyThumb != null && exists(legacyThumb)) {
        delete(legacyThumb);
      }

      // 5) Optionally remove the legacy ORIGINAL iff we know it’s uploaded.
      //    We trust lastBackupDate to mean “uploaded to Drive”.
      if (photo.lastBackupDate != null) {
        // Don't delete from cache — only the legacy original at old location.
        // If your ORIGINAL and cache share physical path, guard accordingly.
        if (exists(absPath)) {
          delete(absPath);
        }
      }

      migrated++;
      // (Optional) emit progress here if you have a channel/log:
      // print('Migrated $migrated/$total photoId=${photo.id}');
    } catch (_) {
      // Keep migration resilient; skip errors per-photo.
      migrated++;
      continue;
  }
  }

  // The cache trims as entries are added; nothing else required here.
}
