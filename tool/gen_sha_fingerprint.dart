#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

import 'keystore.dart';

///
/// Generates an sha fingerprint for the apps certificate.
/// This is used by the .well-known/assetslinks.json for deeplink
/// valiation amongst other possible uses.
///
void main() {
  'keytool -list -v -keystore $keyStorePath -alias $keyStoreAlias'.run;
}
