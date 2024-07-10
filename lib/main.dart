import 'dart:io';

// import 'package:app_links/app_links.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';

import 'crud/customer/customer_list_screen.dart';
import 'crud/job/job_list_screen.dart';
import 'crud/supplier/supplier_list_screen.dart';
import 'crud/system/system_edit_screen.dart';
import 'dao/dao_system.dart';
import 'dao/dao_task.dart';
import 'dao/dao_time_entry.dart';
import 'database/management/backup_providers/email/screen.dart';
import 'database/management/database_helper.dart';
import 'firebase_options.dart';
import 'installer/linux/install.dart' if (kIsWeb) 'util/web_stub.dart';
import 'screens/packing.dart';
import 'screens/shopping.dart';
import 'widgets/blocking_ui.dart';
import 'widgets/hmb_start_time_entry.dart';
import 'widgets/hmb_status_bar.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isNotEmpty) {
    print('Got a link $args');
  } else {
    print('no args');
  }

  initAppLinks();

  final blockingUIKey = GlobalKey();

  runApp(Column(
    children: [
      const BlockingOverlay(),
      Expanded(
        child: ToastificationWrapper(
          child: JuneBuilder(
            TimeEntryState.new,
            builder: (_) => BlockingUIRunner(
              key: blockingUIKey,
              slowAction: _initialise,
              label: 'Upgrade your database.',
              builder: (context) => MaterialApp.router(
                title: 'Handyman',
                theme: ThemeData(
                  primarySwatch: Colors.blue,
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                ),
                routerConfig: _router,
              ),
            ),
          ),
        ),
      ),
    ],
  ));
}

// void main(List<String> args) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   if (args.isNotEmpty) {
//     print('Got a link $args');
//   } else {
//     print('no args');
//   }

//   initAppLinks();

//   // runApp(const MyApp());
//   runApp(ToastificationWrapper(
//       child: MaterialApp.router(
//     title: 'Handyman',
//     theme: ThemeData(
//       primarySwatch: Colors.blue,
//       visualDensity: VisualDensity.adaptivePlatformDensity,
//     ),
//     routerConfig: _router,
//   )));

//   //     navigatorKey: navigatorKey,
//   //     title: 'Handyman',
//   //     theme: ThemeData(
//   //       primarySwatch: Colors.blue,
//   //       visualDensity: VisualDensity.adaptivePlatformDensity,
//   //     ),
//   //     initialRoute: '/',
//   //     onGenerateRoute: (settings) {
//   //       if (settings.name == XeroAuth.redirectPath) {
//   //         HMBToast.info('${settings.arguments}');
//   //         XeroAuth().completeLogin();
//   //       }
//   //       return null;
//   //     },
//   //     home: ChangeNotifierProvider(
//   //       create: (_) => BlockingUI(),
//   //       child: Scaffold(
//   //         body: BlockingUIBuilder<void>(
//   //           future: _initialise,
//   //           stacktrace: StackTrace.current,
//   //           label: 'Upgrade your database.',
//   //           builder: (context, _) =>
//   //               const HomeWithDrawer(initialScreen: JobListScreen()),
//   //         ),
//   //       ),
//   //     ))),
// }

void initAppLinks() {
//   /// Implement deep linking
//   final _appLinks = AppLinks(); // AppLinks is singleton

// // Subscribe to all events (initial link and further)
//   _appLinks.uriLinkStream.listen((uri) {
//     HMBToast.info('Hi from app link');
//     HMBToast.info('Got a link $uri');
//     HMBToast.info('deeplink: $uri');
//     if (uri.path == XeroAuth.redirectPath) {
//       HMBToast.error('Someone asked for xero');
//     }
//   });
}

// // final navigatorKey = GlobalKey<NavigatorState>();

// // class MyApp extends StatelessWidget {
// //   const MyApp({super.key});

// //   @override
// //   Widget build(BuildContext context) => ToastificationWrapper(
// //         child:

// //  MaterialApp(
// //     navigatorKey: navigatorKey,
// //     title: 'Handyman',
// //     theme: ThemeData(
// //       primarySwatch: Colors.blue,
// //       visualDensity: VisualDensity.adaptivePlatformDensity,
// //     ),
// //     initialRoute: '/',
// //     onGenerateRoute: (settings) {
// //       if (settings.name == XeroAuth.redirectPath) {
// //         HMBToast.info('${settings.arguments}');
// //         XeroAuth().completeLogin();
// //       }
// //       return null;
// //     },
// //     home: ChangeNotifierProvider(
// //       create: (_) => BlockingUI(),
// //       child: Scaffold(
// //         body: BlockingUIBuilder<void>(
// //           future: _initialise,
// //           stacktrace: StackTrace.current,
// //           label: 'Upgrade your database.',
// //           builder: (context, _) =>
// //               const HomeWithDrawer(initialScreen: JobListScreen()),
// //         ),
// //       ),
// //     )),
// // );
// //  }

GoRouter get _router => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: BlockingUIRunner(
              slowAction: _initialise,
              label: 'Upgrade your database.',
              builder: (context) =>
                  const HomeWithDrawer(initialScreen: JobListScreen()),
            ),
          ),
          routes: [
            GoRoute(
              path: 'details',
              builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('Details Screen')),
              ),
            ),
          ],
        ),
      ],
    );

class DrawerItem {
  DrawerItem({required this.title, required this.screen});
  final String title;
  final Widget screen;
}

class MyDrawer extends StatelessWidget {
  MyDrawer({super.key});

  final List<DrawerItem> drawerItems = [
    DrawerItem(title: 'Jobs', screen: const JobListScreen()),
    DrawerItem(title: 'Customers', screen: const CustomerListScreen()),
    DrawerItem(title: 'Suppliers', screen: const SupplierListScreen()),
    DrawerItem(title: 'Shopping', screen: const ShoppingScreen()),
    DrawerItem(title: 'Packing', screen: const PackingScreen()),
    DrawerItem(
      title: 'System',
      screen: FutureBuilderEx(
        future: DaoSystem().getById(1),
        builder: (context, system) => SystemEditScreen(system: system!),
      ),
    ),
    DrawerItem(
        title: 'Backup',
        screen: const BackupScreen(
          pathToBackup: '',
        )),
  ];

  @override
  Widget build(BuildContext context) => Drawer(
        child: ListView.builder(
          itemCount: drawerItems.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(drawerItems[index].title),
            onTap: () async {
              final targetRoute = MaterialPageRoute<void>(
                  builder: (context) => HomeWithDrawer(
                        initialScreen: drawerItems[index].screen,
                      ));

              if (drawerItems[index].title == 'System') {
                Navigator.pop(context); // Close the drawer
                await Navigator.push(context, targetRoute);
              } else {
                // Navigator.pop(context); // Close the drawer
                await Navigator.pushReplacement(context, targetRoute);
              }
            },
          ),
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
Future<void> _initialise() async {
  /// The call to _initializeTimeEntryState cause a refresh
  /// which kicks over the BlockingUIBuilder again
  /// causing an endless loop.
  if (!initialised) {
    initialised = true;
    await _checkInstall();
    await _initFirebase();
    await _initDb();
    await _initializeTimeEntryState(refresh: false);
  }
}

Future<void> _initFirebase() async {
  if (!Platform.isLinux) {
    /// We use this for google sigin so we can backup to
    /// the google drive.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _initDb() async {
  await DatabaseHelper().initDatabase();

  // await Future.delayed(const Duration(seconds: 60), () {});

  print('Database located at: ${await DatabaseHelper().pathToDatabase()}');
}

Future<void> _checkInstall() async {
  if (kIsWeb) {
    return;
  }

  final pathToHmbFirstRun = join(await pathToHmbFiles, 'firstrun.txt');
  print('checking firstRun: $pathToHmbFirstRun');

  if (!exists(await pathToHmbFiles)) {
    createDir(await pathToHmbFiles, recursive: true);
  }

  if (!exists(pathToHmbFirstRun)) {
    await _install();
    touch(pathToHmbFirstRun, create: true);
  }
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
