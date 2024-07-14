#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

import 'keystore.dart';

///
/// Generates an sha fingerprint for the apps certificate.
/// This is used by the .well-known/assetslinks.json for deeplink
/// valiation amongst other possible uses.
/// Each time we do a release we need to add the apps signature
/// to deep links.
void main() {
  print(orange('Generating release sha256 key'));
  'keytool -list -v -keystore $keyStorePath -alias $keyStoreAlias'.run;

  print(orange('Generating debug sha256 key'));
  'keytool -list -v -keystore $keyStorePathForDebug -alias $keyStoreAliasForDebug'.run;

  print(green('Check that the ihserver/www_root/.well-known/assetlinks.json file has both of this signatures'));
}
