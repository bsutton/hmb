import 'package:path/path.dart';

int extractVerionForSQLUpgradeScript(String pathToScript) {
  final basename = basenameWithoutExtension(pathToScript);

  return int.parse(basename.substring(1));
}
