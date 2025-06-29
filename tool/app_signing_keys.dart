#! /usr/bin/env dcli

/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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

  print(
    orange(
      'You need to check that the ihserver/www_root/.well-known/assetlinks.json file has both of the SHA256 signatures',
    ),
  );
}
