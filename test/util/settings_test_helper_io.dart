import 'dart:io';

import 'package:hmb/util/dart/paths_dart.dart';

Future<void> prepareSettingsTest() async {}

Future<void> resetSettingsForTest() async {
  final settingsPath = await getSettingsPath();
  final file = File(settingsPath);
  if (file.existsSync()) {
    file.deleteSync();
  }
}
