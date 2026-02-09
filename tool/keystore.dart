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

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

final String projectRoot = DartProject.self.pathToProjectRoot;
// original names
// final keyStorePath = join(projectRoot, 'hmb-key.keystore');
// const keyStoreAlias = 'hmbkey';

final String keyStorePath = join(projectRoot, 'hmb-production.keystore');
const keyStoreAlias = 'hmb-production';

// final keyStorePathForDebug = join(projectRoot, 'hmb-key-debug.keystore');
// const keyStoreAliasForDebug = 'hmb-debug-key';

final String keyStorePathForDebug = join(projectRoot, 'hmb-debug.keystore');
const keyStoreAliasForDebug = 'hmb-debug';
