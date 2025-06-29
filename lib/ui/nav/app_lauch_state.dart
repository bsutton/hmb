/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

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

import '../../api/xero/handyman/app_starts_logging.dart';
import '../../dao/dao.g.dart';
import '../../database/factory/factory.g.dart';
import '../../database/management/backup_providers/local/local_backup_provider.dart';
import '../../database/versions/asset_script_source.dart';
import '../../installer/linux/install.dart';
import '../widgets/widgets.g.dart';

class AppLaunchState {
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
  }

  Future<void> _initializeTimeEntryState({required bool refresh}) async {
    final timeEntryState = June.getState<TimeEntryState>(TimeEntryState.new);
    final activeEntry = await DaoTimeEntry().getActiveEntry();
    if (activeEntry != null) {
      final task = await DaoTask().getById(activeEntry.taskId);
      timeEntryState.setActiveTimeEntry(activeEntry, task, doRefresh: refresh);
    }
  }

  Future<String> get _pathToHmbFiles async =>
      join((await getApplicationSupportDirectory()).path, 'hmb');
}
