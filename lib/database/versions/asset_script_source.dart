import 'dart:convert';

import 'package:flutter/services.dart';

import 'script_source.dart';

class AssetScriptSource implements ScriptSource {
  AssetScriptSource();
  @override
  Future<String> loadSQL(String pathToScript) async =>
      rootBundle.loadString(pathToScript);

  @override
  Future<List<String>> upgradeScripts() async {
    final jsonString = await rootBundle.loadString(ScriptSource.pathToIndex);
    return List<String>.from(json.decode(jsonString) as List);
  }
}
