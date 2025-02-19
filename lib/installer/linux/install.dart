import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:flutter/services.dart';
import 'package:halfpipe/halfpipe.dart';
import 'package:path/path.dart';

Future<void> linuxInstaller() async {
  await _installDeepLinkHander();
}

Future<void> _installDeepLinkHander() async {
  var desktopLauncher = await rootBundle.loadString(
    'assets/installer/linux/hmb.desktop',
  );
  final String pathToExe;

  if (DartScript.self.isCompiled) {
    pathToExe = DartScript.self.pathToExe;
  } else {
    /// for local development we need to run the app using the flutter
    /// as its not compiled.  This lets us test deep links during
    /// dev.
    pathToExe =
        '''flutter run -d linux ${join(DartProject.self.pathToLibDir, 'main.dart')}''';
  }
  desktopLauncher = desktopLauncher.replaceAll(r'$exec$', pathToExe);
  desktopLauncher = desktopLauncher.replaceAll(
    r'$workingDir$',
    DartProject.self.pathToProjectRoot,
  );

  final pathTo = join(HOME, '.local', 'share', 'applications', 'hmb.desktop');
  await File(pathTo).writeAsString(desktopLauncher);

  /// Force an update the of the desktop database so the hmb.desktop
  /// config is registered.
  await HalfPipe()
      .command('update-desktop-database ${dirname(pathTo)}')
      // creates an entry in ~/.config/mimeapps.list
      .command('xdg-mime default hmb.desktop x-scheme-handler/hmb')
      // required by oidc for the secure storage pacakge.
      .exitCode();
}
