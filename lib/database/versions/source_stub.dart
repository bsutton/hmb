import 'script_source.dart';

class AssetScriptSource implements ScriptSource {
  AssetScriptSource();
  @override
  Future<String> loadSQL(String pathToScript) => throw UnimplementedError();

  @override
  Future<List<String>> upgradeScripts() {
    throw UnimplementedError();
  }
}
