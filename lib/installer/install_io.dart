import 'dart:io';

import 'linux/install.dart';
import 'windows/install.dart';

Future<void> install() async {
  if (Platform.isWindows) {
    windowsInstalller();
  } else if (Platform.isLinux) {
    await linuxInstaller();
  } else {
    throw UnsupportedError('Unsupported platform');
  }
}
