import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:toastification/toastification.dart';

import 'api/xero/handyman/app_starts_logging.dart';
import 'dao/dao_task.dart';
import 'dao/dao_time_entry.dart';
import 'database/factory/flutter_database_factory.dart';
import 'database/management/backup_providers/google_drive/google_drive_backup_screen.dart';
import 'database/management/backup_providers/local/local_backup_provider.dart';
import 'database/management/database_helper.dart';
import 'database/versions/asset_script_source.dart';
import 'installer/linux/install.dart' if (kIsWeb) 'util/web_stub.dart';
import 'ui/error.dart';
import 'ui/nav/route.dart';
import 'ui/widgets/blocking_ui.dart';
import 'ui/widgets/hmb_start_time_entry.dart';
import 'ui/widgets/hmb_toast.dart';
import 'ui/widgets/media/desktop_camera_delegate.dart';
import 'util/hmb_theme.dart';
import 'util/log.dart';
import 'util/platform_ex.dart';

bool firstRun = false;

Future<void> main(List<String> args) async {
  Log.configure('.');

  // Ensure WidgetsFlutterBinding is initialized before any async code.
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();
  Log.i('Package Name: ${packageInfo.packageName}');

  // Initialize Sentry.
  await SentryFlutter.init(
    (options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0
        ..profilesSampleRate = 1.0;
      options.experimental.replay.sessionSampleRate = 1.0;
      options.experimental.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () {
      // Perform camera and deeplink init
      initCamera();
      initAppLinks();

      // BlockingUIRunner key
      final blockingUIKey = GlobalKey();

      runApp(
        ToastificationWrapper(
          child: MaterialApp.router(
            theme: theme,
            routerConfig: router,

            // 1) Use `builder` to place your custom logic (BlockingUIRunner).
            // 2) `child` is the routed screen from routerConfig.
            builder:
                (context, mainAppWindow) => Stack(
                  children: [
                    // Added a white border when running on desktop so users can
                    // see the edge of the app.
                    DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isMobile ? Colors.black : Colors.white,
                        ),
                      ),
                      child: JuneBuilder(
                        TimeEntryState.new,
                        builder:
                            (_) => BlockingUITransition(
                              key: blockingUIKey,
                              slowAction: () => _initialise(context),
                              label: 'Upgrading your database.',
                              builder:
                                  (context) =>
                                      mainAppWindow ?? const SizedBox.shrink(),
                            ),
                      ),
                    ),

                    // Overlay used to display a grey overlay
                    // and message when doing long running actions.
                    const BlockingOverlay(),
                  ],
                ),
          ),
        ),
      );
    },
  );
}

ThemeData get theme => ThemeData(
  primaryColor: Colors.deepPurple,
  brightness: Brightness.dark, // This sets the overall theme brightness to dark
  scaffoldBackgroundColor: HMBColors.defaultBackground,
  buttonTheme: const ButtonThemeData(
    buttonColor: Colors.deepPurple,
    textTheme: ButtonTextTheme.primary,
  ),
  snackBarTheme: SnackBarThemeData(
    actionTextColor: HMBColors.accent,
    backgroundColor: Colors.grey.shade800,
    contentTextStyle: const TextStyle(color: Colors.white),
  ),
  timePickerTheme: TimePickerThemeData(
    confirmButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white),
    cancelButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: Colors.white),
  ),
  dialogTheme: const DialogTheme(
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    contentTextStyle: TextStyle(color: Colors.white),
  ),
  colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.deepPurple,
        brightness:
            Brightness.dark, // Add this line to match ThemeData brightness
      )
      .copyWith(secondary: HMBColors.accent)
      .copyWith(surface: HMBColors.defaultBackground),
  visualDensity: VisualDensity.adaptivePlatformDensity,
);

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

bool initialised = false;
Future<void> _initialise(BuildContext context) async {
  if (!initialised) {
    try {
      initialised = true;
      firstRun = await _checkInstall();
      // ignore: use_build_context_synchronously
      await _initDb(context);
      await _initializeTimeEntryState(refresh: false);
      unawaited(logAppStartup());

      // ignore: avoid_catches_without_on_clauses
    } catch (e, stackTrace) {
      // Capture the exception in Sentry
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => FullScreenDialog(
                content: ErrorScreen(errorMessage: e.toString()),
                title: 'Database Error',
              ),
        );
      }
      rethrow;
    }
  }
}

Future<void> _initDb(BuildContext context) async {
  final backupProvider = LocalBackupProvider(FlutterDatabaseFactory());
  try {
    await DatabaseHelper().initDatabase(
      src: AssetScriptSource(),
      backupProvider: backupProvider,
      backup: !kIsWeb,
      databaseFactory: FlutterDatabaseFactory(),
    );
    print('Database located at: ${await backupProvider.databasePath}');
    // ignore: avoid_catches_without_on_clauses
  } catch (e, st) {
    HMBToast.error(
      'Db open failed. Try rebooting your phone or restore the db $e',
    );

    unawaited(Sentry.captureException(e, stackTrace: st));
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const GoogleDriveBackupScreen(),
        ),
      );
    }
  }
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
//   W
//idget build(BuildContext context) => MaterialApp(
//         home: ErrorScreen(errorMessage: errorMessage),
//       );
// }
