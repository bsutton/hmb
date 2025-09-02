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

// lib/state/app_launch_state.dart
import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:june/june.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../api/accounting/accounting_adaptor.dart';
import '../../api/accounting/no_op_accounting_adaptor.dart';
import '../../api/accounting/xero_accounting_adaptor.dart';
import '../../api/xero/handyman/app_starts_logging.dart';
import '../../cache/hmb_image_cache.dart';
import '../../cache/image_compressor.dart';
import '../../dao/dao.g.dart';
import '../../dao/dao_notifications.dart';
import '../../database/factory/factory.g.dart';
import '../../database/management/backup_providers/google_drive/background_backup/photo_sync_service.dart';
import '../../database/management/backup_providers/local/local_backup_provider.dart';
import '../../database/versions/asset_script_source.dart';
import '../../installer/linux/install.dart';
import '../../util/flutter/notifications/local_notifs.dart';
import '../widgets/hmb_start_time_entry.dart';
import '../widgets/media/desktop_camera_delegate.dart';

/// this is were we do all of the heavy initialisation
/// after the Splash screen is up and showing.
class BootStrapper {
  var _isInitialized = false;
  // ignore: omit_obvious_property_types
  bool isFirstRun = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    isFirstRun = await _checkInstall();
    await _initDb();
    await _initializeTimeEntryState(refresh: false);
    unawaited(logAppStartup());
    await _initScheduler();

    // camera & deep link init
    initCamera();
    initAppLinks();
    initPdfrx();
    await initImageCache();

    Dao.notifier = DaoNotifications.notify;

    /// initialise whatever accounting package the
    /// user is using.
    await initAccounting();

    _isInitialized = true;
  }

  Future<bool> _checkInstall() async {
    if (kIsWeb) {
      return false;
    }

    final pathToHmbFirstRun = join(await _pathToHmbFiles, 'firstrun.txt');
    if (!exists(await _pathToHmbFiles)) {
      createDir(await _pathToHmbFiles, recursive: true);
    }

    final firstRun = !exists(pathToHmbFirstRun);
    if (firstRun) {
      if (Platform.isLinux) {
        await linuxInstaller();
      }
      touch(pathToHmbFirstRun, create: true);
    }
    return firstRun;
  }

  Future<void> _initDb() async {
    final backupProvider = LocalBackupProvider(FlutterDatabaseFactory());
    await DatabaseHelper().initDatabase(
      src: AssetScriptSource(),
      backupProvider: backupProvider,
      backup: !kIsWeb,
      databaseFactory: FlutterDatabaseFactory(),
    );
    print('Database located at: ${await backupProvider.databasePath}');
  }

  Future<void> _initScheduler() async {
    final openTodos = await DaoToDo().getOpenWithReminders();
    await LocalNotifs().resyncFromToDos(openTodos);
  }

  Future<void> _initializeTimeEntryState({required bool refresh}) async {
    final timeEntryState = June.getState<ActiveTimeEntryState>(
      ActiveTimeEntryState.new,
    );
    final activeEntry = await DaoTimeEntry().getActiveEntry();
    if (activeEntry != null) {
      final task = await DaoTask().getById(activeEntry.taskId);
      timeEntryState.setActiveTimeEntry(activeEntry, task, doRefresh: refresh);
    }
  }

  Future<String> get _pathToHmbFiles async =>
      join((await getApplicationSupportDirectory()).path, 'hmb');

  void initCamera() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      /// Add camera support to Image Picker on Windows.
      DesktopCameraDelegate.register();
    }
  }

  void initAppLinks() {
    // Uncomment and implement deep linking if needed
    // final _appLinks = AppLinks(); // AppLinks is singleton

    // Subscribe to all events (initial link and further)
    // _appLinks.uriLinkStream.listen((uri) {
    //   HMBToast.info('Hi from app link');
    //   HMBToast.info('Got a link $uri');
    //   HMBToast.info('deeplink: $uri');
    //   if (uri.path == XeroAuth.redirectPath) {
    //     HMBToast.error('Someone asked for xero');
    //   }
    // });
  }

  void initPdfrx() {
    pdfrxFlutterInitialize();
  }

  Future<void> initImageCache() async {
    await HMBImageCache().init(
      (variant) async => PhotoSyncService().download(
        variant.meta.photo.id,
        variant.cacheStoragePath,
        await variant.cloudStoragePath,
      ),
      ImageCompressor.run,
    );
  }

  Future<void> initAccounting() async {
    if (await AccountingAdaptor.isEnabled) {
      AccountingAdaptor.instance = XeroAccountingAdaptor();
    } else {
      AccountingAdaptor.instance = NoOpAccountingAdaptor();
    }
  }
}
