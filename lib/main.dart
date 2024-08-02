import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:toastification/toastification.dart';

import 'crud/customer/customer_list_screen.dart';
import 'crud/job/job_list_screen.dart';
import 'crud/supplier/supplier_list_screen.dart';
import 'crud/system/system_billing_screen.dart';
import 'crud/system/system_business_screen.dart';
import 'crud/system/system_contact_screen.dart';
import 'crud/system/system_integration_screen.dart';
import 'dao/dao_task.dart';
import 'dao/dao_time_entry.dart';
import 'database/management/backup_providers/email/screen.dart';
import 'database/management/database_helper.dart';
import 'installer/linux/install.dart' if (kIsWeb) 'util/web_stub.dart';
import 'screens/about.dart';
import 'screens/error.dart';
import 'screens/packing.dart';
import 'screens/shopping.dart';
import 'screens/wizard/wizard.dart';
import 'widgets/blocking_ui.dart';
import 'widgets/full_screen_photo_view.dart';
import 'widgets/hmb_start_time_entry.dart';
import 'widgets/hmb_status_bar.dart';

bool firstRun = false;

void main(List<String> args) async {
  await SentryFlutter.init(
    (options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0
        ..profilesSampleRate = 1.0;
    },
    appRunner: () {
      WidgetsFlutterBinding.ensureInitialized();

      if (args.isNotEmpty) {
        print('Got a link $args');
      } else {
        print('no args');
      }

      initAppLinks();

      final blockingUIKey = GlobalKey();

      // Set up error handling
      FlutterError.onError = (details) {
        // Log the error to the console
        FlutterError.dumpErrorToConsole(details);

        // Capture the exception in Sentry
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        );

        // Optionally, navigate to the ErrorScreen
        runApp(ErrorApp(details.exception.toString()));
      };

      // Catch errors in asynchronous code
      runZonedGuarded(
        () {
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
                              visualDensity:
                                  VisualDensity.adaptivePlatformDensity,
                            ),
                            routerConfig: _router,
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
        (error, stackTrace) {
          // Capture the exception in Sentry
          Sentry.captureException(
            error,
            stackTrace: stackTrace,
          );

          // Optionally, navigate to the ErrorScreen
          runApp(ErrorApp(error.toString()));
        },
      );
    },
  );
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

GoRouter get _router => GoRouter(
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: '/',
          // ignore: prefer_expression_function_bodies
          redirect: (context, state) {
            return firstRun ? '/system/wizard' : null;
          },
          builder: (_, __) =>
              const HomeWithDrawer(initialScreen: JobListScreen()),
          routes: [
            GoRoute(
              path: 'error',
              builder: (context, state) {
                final errorMessage = state.extra as String? ?? 'Unknown Error';
                return ErrorScreen(errorMessage: errorMessage);
              },
            ),
            GoRoute(
              path: 'jobs',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: JobListScreen()),
            ),
            GoRoute(
              path: 'customers',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: CustomerListScreen()),
            ),
            GoRoute(
              path: 'suppliers',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: SupplierListScreen()),
            ),
            GoRoute(
              path: 'shopping',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: ShoppingScreen()),
            ),
            GoRoute(
              path: 'packing',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: PackingScreen()),
            ),
            GoRoute(
              path: 'system/business',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: SystemBusinessScreen()),
            ),
            GoRoute(
              path: 'system/billing',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: SystemBillingScreen()),
            ),
            GoRoute(
              path: 'system/contact',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: SystemContactInformationScreen()),
            ),
            GoRoute(
              path: 'system/integration',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: SystemIntegrationScreen()),
            ),
            GoRoute(
              path: 'system/about',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: AboutScreen()),
            ),
            GoRoute(
              path: 'system/backup',
              builder: (_, __) => const HomeWithDrawer(
                  initialScreen: BackupScreen(pathToBackup: '')),
            ),
            GoRoute(
              path: 'system/wizard',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: FirstRunWizard()),
            ),
            GoRoute(
              path: 'xero/auth_complete',
              builder: (_, __) =>
                  const HomeWithDrawer(initialScreen: AboutScreen()),
            ),
            GoRoute(
              path: 'photo_viewer',
              builder: (context, state) {
                final args = state.extra! as Map<String, String>;
                final imagePath = args['imagePath']!;
                final taskName = args['taskName']!;
                final comment = args['comment']!;
                return FullScreenPhotoViewer(
                    imagePath: imagePath, taskName: taskName, comment: comment);
              },
            ),
          ],
        ),
      ],
    );

class DrawerItem {
  DrawerItem({required this.title, required this.route, this.children});
  final String title;
  final String route;
  final List<DrawerItem>? children;
}

class MyDrawer extends StatelessWidget {
  MyDrawer({super.key});

  final List<DrawerItem> drawerItems = [
    DrawerItem(title: 'Jobs', route: '/jobs'),
    DrawerItem(title: 'Customers', route: '/customers'),
    DrawerItem(title: 'Suppliers', route: '/suppliers'),
    DrawerItem(title: 'Shopping', route: '/shopping'),
    DrawerItem(title: 'Packing', route: '/packing'),
    DrawerItem(
      title: 'System',
      route: '',
      children: [
        DrawerItem(title: 'Business', route: '/system/business'),
        DrawerItem(title: 'Billing', route: '/system/billing'),
        DrawerItem(title: 'Contact', route: '/system/contact'),
        DrawerItem(title: 'Integration', route: '/system/integration'),
        DrawerItem(title: 'Setup Wizard', route: '/system/wizard'),
        DrawerItem(title: 'About', route: '/system/about'),
        DrawerItem(title: 'Backup', route: '/system/backup'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Drawer(
        child: ListView.builder(
          itemCount: drawerItems.length,
          itemBuilder: (context, index) {
            final item = drawerItems[index];
            return item.children != null
                ? ExpansionTile(
                    title: Text(item.title),
                    children: item.children!
                        .map((child) => ListTile(
                              title: Text(child.title),
                              onTap: () {
                                Navigator.pop(context); // Close the drawer
                                context.go(child.route);
                              },
                            ))
                        .toList(),
                  )
                : ListTile(
                    title: Text(item.title),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      context.go(item.route);
                    },
                  );
          },
        ),
      );
}

class HomeWithDrawer extends StatelessWidget {
  const HomeWithDrawer({required this.initialScreen, super.key});
  final Widget initialScreen;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Handyman'),
        ),
        drawer: MyDrawer(),
        body: Column(
          children: [
            JuneBuilder<TimeEntryState>(
              TimeEntryState.new,
              builder: (context) {
                final state = June.getState<TimeEntryState>(TimeEntryState.new);
                if (state.activeTimeEntry != null) {
                  return HMBStatusBar(
                    activeTimeEntry: state.activeTimeEntry,
                    task: state.task,
                    onTimeEntryEnded: state.clearActiveTimeEntry,
                  );
                }
                return Container();
              },
            ),
            Expanded(child: initialScreen),
          ],
        ),
      );
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
      Sentry.captureException(e, stackTrace: stackTrace);

      if (context.mounted) {
        await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => FullScreenDialog(
                  content: ErrorScreen(errorMessage: e.toString()),
                  title: 'Database Error',
                ));
        // context.go('/error',
        //     extra: 'An error occurred while processing your request.');
      }
      rethrow;
    }
  }
}

// Future<void> _initFirebase() async {
//   if (!Platform.isLinux) {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//   }
// }

Future<void> _initDb() async {
  await DatabaseHelper().initDatabase();
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

class ErrorApp extends StatelessWidget {
  const ErrorApp(this.errorMessage, {super.key});
  final String errorMessage;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: ErrorScreen(errorMessage: errorMessage),
      );
}
