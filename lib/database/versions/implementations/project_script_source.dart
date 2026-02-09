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

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

import '../script_source.dart';

class ProjectScriptSource implements ScriptSource {
  ProjectScriptSource();

  @override
  Future<String> loadSQL(String pathToScript) async =>
      read(pathToScript).toParagraph();

  @override
  Future<List<String>> upgradeScripts() async {
    final project = DartProject.self;
    final jsonString = read(
      join(project.pathToProjectRoot, ScriptSource.pathToIndex),
    ).toParagraph();

    return List<String>.from(json.decode(jsonString) as List);
  }
}
