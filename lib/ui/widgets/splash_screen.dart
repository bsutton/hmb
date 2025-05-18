import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/xero/handyman/app_starts_logging.dart';
import '../../dao/dao.g.dart';
import '../../database/factory/factory.g.dart';
import '../../database/management/backup_providers/local/local_backup_provider.dart';
import '../../database/versions/asset_script_source.dart';
import '../../installer/linux/install.dart';
import '../dialog/database_error_dialog.dart';
import 'widgets.g.dart';

// ignore: omit_obvious_property_types
bool firstRun = false;

// re-use your blocking UI key
final _blockingUIKey = GlobalKey();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) => BlockingUITransition(
    key: _blockingUIKey,
    slowAction: () => _initialise(context),
    builder: (context) => const SizedBox.shrink(),
    errorBuilder:
        (context, error) => DatabaseErrorDialog(error: error.toString()),
  );

  Future<bool> _checkInstall() async {
    if (kIsWeb) {
      return false;
    }

    final pathToHmbFirstRun = join(await pathToHmbFiles, 'firstrun.txt');
    print('checking firstRun: $pathToHmbFirstRun');

    if (!exists(await pathToHmbFiles)) {
      createDir(await pathToHmbFiles, recursive: true);
    }

    final firstRun = !exists(pathToHmbFirstRun);
    if (firstRun) {
      await _install();
      touch(pathToHmbFirstRun, create: true);
    }
    return firstRun;
  }

  Future<void> _install() async {
    if (Platform.isLinux) {
      await linuxInstaller();
    }
  }

  var _initialised = false;
  Future<void> _initialise(BuildContext context) async {
    if (!_initialised) {
      // try {
      _initialised = true;
      firstRun = await _checkInstall();
      // ignore: use_build_context_synchronously
      await _initDb(context);
      await _initializeTimeEntryState(refresh: false);
      unawaited(logAppStartup());

      // ignore: avoid_catches_without_on_clauses
      // } catch (e, stackTrace) {
      //   // Capture the exception in Sentry
      //   unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      //   if (context.mounted) {
      //     await showDialog<void>(
      //       context: context,
      //       barrierDismissible: false,
      //       builder: (_) => ErrorScreen(errorMessage: e.toString()),
      //     );
      //   }
      //   if (context.mounted) {
      //     context.go('system/backup/google');
      //   }
      // }
    }
    if (context.mounted) {
      context.go('/home');
    }
  }

  Future<void> _initDb(BuildContext context) async {
    final backupProvider = LocalBackupProvider(FlutterDatabaseFactory());
    await DatabaseHelper().initDatabase(
      src: AssetScriptSource(),
      backupProvider: backupProvider,
      backup: !kIsWeb,
      databaseFactory: FlutterDatabaseFactory(),
    );
    print('Database located at: ${await backupProvider.databasePath}');
  }

  Future<void> _initializeTimeEntryState({required bool refresh}) async {
    final timeEntryState = June.getState<TimeEntryState>(TimeEntryState.new);
    final activeEntry = await DaoTimeEntry().getActiveEntry();
    if (activeEntry != null) {
      final task = await DaoTask().getById(activeEntry.taskId);
      timeEntryState.setActiveTimeEntry(activeEntry, task, doRefresh: refresh);
    }
  }

  Future<String> get pathToHmbFiles async =>
      join((await getApplicationSupportDirectory()).path, 'hmb');
}
