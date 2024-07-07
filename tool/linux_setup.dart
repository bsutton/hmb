#! /usr/bin/env dcli

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
      .start(privileged: true);

  if (!exists(keyStorePath)) {
    print(red('''
creating signing key - store this VERY SAFELEY - under "HMB keystore"'''));
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

    print(orange('''
Your keystore has been created $keyStorePath. Backup it up to lastpass'''));

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
