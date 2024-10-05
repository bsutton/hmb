import 'dart:convert';

import 'package:dcli/dcli.dart';
import 'package:path/path.dart';

import 'script_source.dart';

class ProjectScriptSource implements ScriptSource {
  ProjectScriptSource();

  @override
  Future<String> loadSQL(String pathToScript) async =>
      read(pathToScript).toParagraph();

  @override
  Future<List<String>> upgradeScripts() async {
    final project = DartProject.self;
    final jsonString =
        read(join(project.pathToProjectRoot, ScriptSource.pathToIndex))
            .toParagraph();

    return List<String>.from(json.decode(jsonString) as List);
  }
}
