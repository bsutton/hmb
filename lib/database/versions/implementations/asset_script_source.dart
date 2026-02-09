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

import 'dart:convert';

import 'package:flutter/services.dart';

import '../script_source.dart';

class AssetScriptSource implements ScriptSource {
  AssetScriptSource();
  @override
  Future<String> loadSQL(String pathToScript) =>
      rootBundle.loadString(pathToScript);

  @override
  Future<List<String>> upgradeScripts() async {
    final jsonString = await rootBundle.loadString(ScriptSource.pathToIndex);
    return List<String>.from(json.decode(jsonString) as List);
  }
}
