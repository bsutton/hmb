import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:dcli_core/dcli_core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import 'crud/customer/customer_list_screen.dart';
import 'crud/job/job_list_screen.dart';
import 'crud/supplier/supplier_list_screen.dart';
import 'crud/system/system_edit_screen.dart';
import 'dao/dao_system.dart';
import 'database/management/backup_providers/email/screen.dart';
import 'database/management/database_helper.dart';
import 'firebase_options.dart';
import 'installer/linux/install.dart';
import 'screens/packing.dart';
import 'screens/shopping.dart';
import 'widgets/blocking_ui.dart';
import 'widgets/hmb_toast.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.isNotEmpty) {
    print('Got a link $args');
  } else {
    print('no args');
  }

  /// Implement deep linking
  final _appLinks = AppLinks(); // AppLinks is singleton

// Subscribe to all events (initial link and further)
  _appLinks.uriLinkStream.listen((uri) {
    print('Hi from app link');
    HMBToast.info('Got a link $uri');
    print('deeplink: $uri');
    if (uri.path == ('/xero/auth_callback')) {
      HMBToast.info('Somonee asked for xero');
    }
  });

  runApp(const MyApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => ToastificationWrapper(
        child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Handyman',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            initialRoute: '/',
            home: ChangeNotifierProvider(
              create: (_) => BlockingUI(),
              child: Scaffold(
                body: BlockingUIBuilder<void>(
                  future: _initialise,
                  stacktrace: StackTrace.current,
                  label: 'Upgrade your database.',
                  builder: (context, _) =>
                      const HomeWithDrawer(initialScreen: JobListScreen()),
                ),
              ),
            )),
      );
}

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
        body: initialScreen,
      );
}

Future<void> _initialise() async {
  await _checkInstall();
  await _initFirebase();
  await _initDb();
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

Future<String> get pathToHmbFiles async =>
    join((await getApplicationSupportDirectory()).path, 'hmb');
