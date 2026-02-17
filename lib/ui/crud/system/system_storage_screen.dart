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

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../cache/hmb_image_cache.dart';
import '../../../cache/image_cache_config.dart';
import '../../../dao/dao_image_cache_variant.dart';
import '../../../dao/dao_photo.dart';
import '../../../dao/dao_system.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/icons/help_button.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/save_and_close.dart';
import '../../widgets/text/hmb_text_themes.dart';

class StorageStats {
  final int photoCount;
  final int unsyncedPhotoCount;
  final int totalBytes;

  const StorageStats({
    required this.photoCount,
    required this.unsyncedPhotoCount,
    required this.totalBytes,
  });

  static Future<StorageStats> load() async {
    final dao = DaoImageCacheVariant();
    final photoCount = await dao.totalPhotos();
    final unsyncedPhotoCount = await DaoPhoto().countUnsyncedPhotos();
    final totalBytes = await dao.totalBytes();
    return StorageStats(
      photoCount: photoCount,
      unsyncedPhotoCount: unsyncedPhotoCount,
      totalBytes: totalBytes,
    );
  }
}

class SystemStorageScreen extends StatefulWidget {
  final bool showButtons;

  const SystemStorageScreen({super.key, this.showButtons = true});

  @override
  State<SystemStorageScreen> createState() => SystemStorageScreenState();
}

class SystemStorageScreenState extends DeferredState<SystemStorageScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _photoCacheMaxMbController;
  var _stats = const StorageStats(
    photoCount: 0,
    unsyncedPhotoCount: 0,
    totalBytes: 0,
  );

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Storage');
    final system = await DaoSystem().get();
    _photoCacheMaxMbController = TextEditingController(
      text: system.photoCacheMaxMb.toString(),
    );
    _stats = await StorageStats.load();
  }

  @override
  void dispose() {
    _photoCacheMaxMbController.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }

    final cacheMb = int.parse(_photoCacheMaxMbController.text);
    final system = await DaoSystem().get();
    system.photoCacheMaxMb = cacheMb;
    await DaoSystem().update(system);
    await HMBImageCache().updateMaxBytes(cacheMb * 1024 * 1024);
    await _reloadStats();

    if (mounted) {
      setState(() {});
      HMBToast.info('saved');
      if (close) {
        context.go('/home/settings');
      }
    }
    return true;
  }

  Future<void> _reloadStats() async {
    _stats = await StorageStats.load();
    if (mounted) {
      setState(() {});
    }
  }

  bool get _cacheLimitExceeded {
    final maxMb = int.tryParse(_photoCacheMaxMbController.text) ?? 0;
    return _stats.totalBytes > (maxMb * 1024 * 1024);
  }

  Future<void> _trimBackedUpNow() async {
    final cacheMb = int.tryParse(_photoCacheMaxMbController.text);
    if (cacheMb == null || cacheMb <= 0) {
      HMBToast.error('Enter a valid cache size before trimming.');
      return;
    }
    await HMBImageCache().updateMaxBytes(cacheMb * 1024 * 1024);
    await _reloadStats();
    HMBToast.info('Cache trim complete.');
  }

  Future<void> _forceTrimWithDataLoss() async {
    final cacheMb = int.tryParse(_photoCacheMaxMbController.text);
    if (cacheMb == null || cacheMb <= 0) {
      HMBToast.error('Enter a valid cache size before trimming.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Unsynced Photos?'),
        content: const Text(
          'This will permanently delete unsynced local photos to reduce cache '
          'usage. These photos cannot be recovered unless already backed up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Photos'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) {
      return;
    }

    final maxBytes = cacheMb * 1024 * 1024;
    final cacheDao = DaoImageCacheVariant();
    final photoDao = DaoPhoto();
    var total = await cacheDao.totalBytes();

    while (total > maxBytes) {
      final oldest = await cacheDao.oldest();
      if (oldest == null) {
        break;
      }
      final photo = await photoDao.getById(oldest.photoId);
      if (photo != null && photo.lastBackupDate == null) {
        await photoDao.deleteLocalOnly(photo.id);
      } else {
        await HMBImageCache().evictPhoto(oldest.photoId.toString());
      }
      total = await cacheDao.totalBytes();
    }

    await _reloadStats();
    HMBToast.info('Forced cache trim complete.');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showButtons) {
      return Scaffold(
        body: HMBColumn(
          children: [
            SaveAndClose(
              onSave: save,
              showSaveOnly: false,
              onCancel: () async => context.pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildForm(),
              ),
            ),
          ],
        ),
      );
    }

    return _buildForm();
  }

  Widget _buildForm() => DeferredBuilder(
    this,
    builder: (context) => Form(
      key: _formKey,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HMBTextField(
            controller: _photoCacheMaxMbController,
            labelText: 'Photo Cache Size (MB)',
            keyboardType: TextInputType.number,
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return 'Enter a size in MB greater than 0';
              }
              return null;
            },
          ).help('Photo Cache Size', '''
Maximum local photo-cache size in megabytes.
Default is ${ImageCacheConfig.defaultMaxMegabytes}MB.'''),
          const HMBSpacer(height: true),
          const HMBTextHeadline2('Current Cache Usage'),
          HMBTextLine('Photos cached locally: ${_stats.photoCount}'),
          HMBTextLine('Unsynced photos: ${_stats.unsyncedPhotoCount}'),
          HMBTextLine('Space used: ${_formatBytes(_stats.totalBytes)}'),
          const HMBSpacer(height: true),
          HMBButtonPrimary(
            label: 'Trim Backed-up Cache',
            hint: 'Trim cache using only photos that were already synced',
            onPressed: _trimBackedUpNow,
          ),
          if (_cacheLimitExceeded && _stats.unsyncedPhotoCount > 0) ...[
            const HMBSpacer(height: true),
            const Text(
              'Cache is still over the limit because unsynced photos are being '
              'kept to avoid data loss.',
            ),
            const HMBSpacer(height: true),
            HMBButtonSecondary(
              label: 'Force Trim (Delete Unsynced Photos)',
              hint: 'Permanently delete unsynced photos to reduce cache usage',
              onPressed: _forceTrimWithDataLoss,
            ),
          ],
        ],
      ),
    ),
  );

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
