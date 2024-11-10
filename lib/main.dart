import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:toastification/toastification.dart';

import 'dao/dao_task.dart';
import 'dao/dao_time_entry.dart';
import 'database/factory/flutter_database_factory.dart';
import 'database/management/backup_providers/local/local_backup_provider.dart';
import 'database/management/database_helper.dart';
import 'database/versions/asset_script_source.dart';
import 'installer/linux/install.dart' if (kIsWeb) 'util/web_stub.dart';
import 'nav/route.dart';
import 'screens/error.dart';
import 'widgets/blocking_ui.dart';
import 'widgets/hmb_start_time_entry.dart';
import 'widgets/media/windows_camera_delegate.dart';

bool firstRun = false;

void main(List<String> args) async {
  // Ensure WidgetsFlutterBinding is initialized before any async code.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry.
  await SentryFlutter.init(
    (options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0
        ..profilesSampleRate = 1.0;
    },
    appRunner: () {
      initCamera();
      initAppLinks();

      final blockingUIKey = GlobalKey();

      runApp(ToastificationWrapper(
        child: MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => JuneBuilder(
                    TimeEntryState.new,
                    builder: (_) => BlockingUIRunner(
                      key: blockingUIKey,
                      slowAction: () => _initialise(context),
                      label: 'Upgrade your database.',
                      builder: (context) => MaterialApp.router(
                        title: 'Handyman',
                        theme: ThemeData(
                          primarySwatch: Colors.blue,
                          visualDensity: VisualDensity.adaptivePlatformDensity,
                        ),
                        routerConfig: router,
                      ),
                    ),
                  ),
                ),
              ),
              const BlockingOverlay(),
            ],
          ),
        ),
      ));
    },
  );
}

void initCamera() {
  if (Platform.isWindows) {
    /// Add camera support to Image Picker on Windows.
    WindowsCameraDelegate.register();
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

bool initialised = false;
Future<void> _initialise(BuildContext context) async {
  if (!initialised) {
    try {
      initialised = true;
      firstRun = await _checkInstall();
      // await _initFirebase();
      await _initDb();
      await _initializeTimeEntryState(refresh: false);

      // ignore: avoid_catches_without_on_clauses
    } catch (e, stackTrace) {
      // Capture the exception in Sentry
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (context.mounted) {
        await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => FullScreenDialog(
                  content: ErrorScreen(errorMessage: e.toString()),
                  title: 'Database Error',
                ));
      }
      rethrow;
    }
  }
}

Future<void> _initDb() async {
  await DatabaseHelper().initDatabase(
      src: AssetScriptSource(),
      backupProvider: LocalBackupProvider(FlutterDatabaseFactory()),
      backup: !kIsWeb,
      databaseFactory: FlutterDatabaseFactory());
  print('Database located at: ${await DatabaseHelper().pathToDatabase()}');
}

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

// class ErrorApp extends StatelessWidget {
//   const ErrorApp(this.errorMessage, {super.key});
//   final String errorMessage;

//   @override
//   Widget build(BuildContext context) => MaterialApp(
//         home: ErrorScreen(errorMessage: errorMessage),
//       );
// }
