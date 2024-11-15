#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

import 'keystore.dart';

///
/// To upload an app to google play we need to sign the app.
/// The certificates are stored in a pair of keystores, one for
/// the production app and one for the debug build.
///
/// The keystores are backed up in lastpass under:
///   HMB keystore for app signing
///
/// The certificates/sha fingerprints are used by
/// Google Play and the .well-known/assetslinks.json for deeplink
/// valiation amongst other possible uses.
///
///
void main() {
  print(orange('Display production sha256 fingerprint'));
  'keytool -list -v -keystore $keyStorePath -alias $keyStoreAlias'.run;

  print(orange('Generating debug sha256 key'));
  'keytool -list -v -keystore $keyStorePathForDebug '
          '-alias $keyStoreAliasForDebug'
      .run;

  print(orange(
      'You need to check that the ihserver/www_root/.well-known/assetlinks.json file has both of the SHA256 signatures'));
}
