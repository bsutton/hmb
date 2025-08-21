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

// lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:toastification/toastification.dart';

import 'ui/nav/route.dart'; // your existing router defs
import 'ui/widgets/blocking_ui.dart';
import 'ui/widgets/desktop_back_gesture.dart';
import 'ui/widgets/media/desktop_camera_delegate.dart';
import 'util/hmb_theme.dart';
import 'util/log.dart';
import 'util/platform_ex.dart';

//----------------------------------------------------------------------

// the navigator key you already passed into GoRouter
final _rootNavKey = GlobalKey<NavigatorState>();

//----------------------------------------------------------------------

Future<void> main(List<String> args) async {
  Log.configure('.');

  // ensure Flutter binding before any async work
  SentryWidgetsFlutterBinding.ensureInitialized();

  // grab package info for logging
  final packageInfo = await PackageInfo.fromPlatform();
  Log.i('Package Name: ${packageInfo.packageName}');

  // initialize Sentry
  await SentryFlutter.init(
    (options) {
      options
        ..dsn =
            'https://17bb41df4a5343530bfcb92553f4c5a7@o4507706035994624.ingest.us.sentry.io/4507706038157312'
        ..tracesSampleRate = 1.0
        ..profilesSampleRate = 1.0;
      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () {
      // camera & deep link init
      initCamera();
      initAppLinks();

      // finally launch the app
      runApp(const HmbApp());
    },
  );
}

//----------------------------------------------------------------------

class HmbApp extends StatelessWidget {
  const HmbApp({super.key});

  @override
  Widget build(BuildContext context) => ToastificationWrapper(
    child: MaterialApp.router(
      theme: theme,
      routerConfig: createGoRouter(_rootNavKey), // unchanged
      builder: (context, mainAppWindow) => DesktopBackGesture(
        navigatorKey: _rootNavKey,
        child: Stack(
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
              child: mainAppWindow ?? const SizedBox.shrink(),
            ),

            //  an overlay for blocking UI during long operations
            const BlockingOverlay(),
          ],
        ),
      ),
    ),
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
  ).data,
  colorScheme:
      ColorScheme.fromSwatch(
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
