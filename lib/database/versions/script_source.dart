abstract class ScriptSource {
  Future<String> loadSQL(String pathToScript);
  Future<List<String>> upgradeScripts();

  static const pathToIndex = 'assets/sql/upgrade_list.json';
}
