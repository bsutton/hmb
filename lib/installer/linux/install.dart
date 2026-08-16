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

import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:flutter/services.dart';
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
  await _runCommand('update-desktop-database', [dirname(pathTo)]);

  // Creates an entry in ~/.config/mimeapps.list. This is required by OIDC
  // for the secure storage package.
  await _runCommand('xdg-mime', [
    'default',
    'hmb.desktop',
    'x-scheme-handler/hmb',
  ]);
}

Future<void> _runCommand(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr.toString(),
      result.exitCode,
    );
  }
}
