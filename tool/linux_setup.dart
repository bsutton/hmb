#! /usr/bin/env dcli
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
import 'package:path/path.dart';

import 'keystore.dart';

/// setup script to help get a linux (ubuntu) dev environment working.
void main() {
  'apt install --assume-yes '
          /// The flutter package flutter_secure_storage_linux needs these
          /// lib deps.
          'libsecret-1-dev libsecret-tools '
          ' libjsoncpp-dev libsecret-1-0 '
          // required by oidc for the secure storage pacakge. If
          // you are running KDE then this needs to be changed ksecretservices.
          ' gnome-keyring '
          'clang cmake git '
          'ninja-build pkg-config '
          'libgtk-3-dev liblzma-dev '
          'libstdc++-12-dev '
          'libsqlite3-dev '
      .start(privileged: true);

  _verifySecureStoragePrerequisites();

  _createReleaseKeyStore();
  _createDebugKeyStore();
}

void _verifySecureStoragePrerequisites() {
  _requireCommand('secret-tool');
  _requireCommand('gnome-keyring-daemon');

  if ((Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ?? '').isEmpty) {
    throw StateError('''
DBUS_SESSION_BUS_ADDRESS is not set.
The Linux keyring is not available in this shell, so secure storage will fail.
Start a desktop session or launch the shell under dbus-run-session.
''');
  }

  final user = Platform.environment['USER'] ?? 'hmb';
  const service = 'hmb-linux-setup';
  final account = '$user-secure-storage-check';
  const secret = 'hmb-linux-setup-secret';

  final store = Process.runSync('bash', [
    '-lc',
    '''
set -e
printf '%s' '$secret' | secret-tool store
  --label='HMB Linux Setup'
  service '$service'
  account '$account' >/dev/null
''',
  ]);
  if (store.exitCode != 0) {
    throw StateError('''
Failed to write to the Linux keyring.
stderr:
${store.stderr}
Ensure gnome-keyring is running and the login keyring is unlocked.
''');
  }

  final lookup = Process.runSync('secret-tool', [
    'lookup',
    'service',
    service,
    'account',
    account,
  ]);
  final retrieved = (lookup.stdout as String).trim();

  final clear = Process.runSync('secret-tool', [
    'clear',
    'service',
    service,
    'account',
    account,
  ]);

  if (lookup.exitCode != 0 || clear.exitCode != 0 || retrieved != secret) {
    throw StateError('''
The Linux keyring round-trip check failed.
lookup exit: ${lookup.exitCode}
clear exit: ${clear.exitCode}
retrieved: $retrieved
Ensure gnome-keyring is running and accessible from this shell.
''');
  }

  print(green('Linux secure storage is available.'));
}

void _requireCommand(String command) {
  final result = Process.runSync('bash', ['-lc', 'command -v $command']);
  if (result.exitCode != 0) {
    throw StateError('$command is not installed or is not available on PATH.');
  }
}

/// Keystore used to generate the sha fingerprint required to
/// sign the app and for deep links to work.
void _createReleaseKeyStore() {
  if (!exists(keyStorePath)) {
    print(
      red('''
creating signing key - store this VERY SAFELEY - under "HMB keystore"'''),
    );
    var bad = false;
    String password;
    String confirmed;
    do {
      if (bad) {
        printerr('passwords do not match');
      }
      password = ask('Keystore Password');
      confirmed = ask('Confirm password');
      bad = true;
    } while (password != confirmed);

    /// build keystore for app signing
    /// Uses the standard java keytool
    'keytool -genkey -v '
            '-keystore $keyStorePath '
            '-storepass $password '
            '-alias $keyStoreAlias '
            '-keyalg RSA '
            '-keysize 2048 '
            '-validity 10000 '
        .start(terminal: true);

    print(
      orange('''
Your keystore has been created $keyStorePath. Backup it up to lastpass'''),
    );

    join(projectRoot, 'android', 'key.properties').write('''
storePassword=$password
keyPassword=$password
keyAlias=$keyStoreAlias
storeFile=$keyStorePath
    ''');
  } else {
    print(orange('Using existing keystore $keyStorePath'));
  }
}

/// Key store to generate sha finger print for deep links when debugging.
void _createDebugKeyStore() {
  if (!exists(keyStorePathForDebug)) {
    print(
      red('''
creating debug signing key - store this VERY SAFELEY - under "HMB keystore"'''),
    );
    var bad = false;
    String password;
    String confirmed;
    do {
      if (bad) {
        printerr('passwords do not match');
      }
      password = ask('Keystore Password');
      confirmed = ask('Confirm password');
      bad = true;
    } while (password != confirmed);

    /// build keystore for app signing
    /// Uses the standard java keytool
    'keytool -genkey -v '
            '-keystore $keyStorePathForDebug '
            '-storepass $password '
            '-alias $keyStoreAliasForDebug '
            '-keyalg RSA '
            '-keysize 2048 '
            '-validity 10000 '
        .start(terminal: true);

    print(
      orange(
        '''
Your keystore has been created $keyStorePathForDebug. Backup it up to lastpass''',
      ),
    );

    join(projectRoot, 'android', 'key.properties').write('''
storePassword=$password
keyPassword=$password
keyAlias=$keyStoreAliasForDebug
storeFile=$keyStorePathForDebug
    ''');
  } else {
    print(orange('Using existing debug keystore $keyStorePathForDebug'));
  }
}
