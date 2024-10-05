#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

/// setup script to help get a linux (ubuntu) dev environment working.
void main() {
  // if (!Shell.current.isPrivilegedUser) {
  //   Shell.current.privilegesRequiredMessage('windows_setup.dart');
  // }

  /// Install sqllite3.dll into the windows system32 folder
  /// so that our CLI tooling can access the database.
  final systemPath = join(rootPath, 'windows', 'system32');
  final installedPath = join(systemPath, 'sqlite3.dll');
  if (exists(installedPath)) {
    /// make certain we always have the latest version
    /// from the project.
    delete(installedPath);
  }
  copy(join('windows', 'sqlite3.dll'), systemPath);

  // _createReleaseKeyStore();
  // _createDebugKeyStore();
}
