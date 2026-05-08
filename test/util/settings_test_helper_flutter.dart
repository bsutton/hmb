import 'dart:io';

import 'package:flutter_test/flutter_test.dart' as t;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

Future<void> prepareSettingsTest() async {
  t.TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();
}

Future<void> resetSettingsForTest() async {
  final settingsPath = await PathProviderPlatform.instance
      .getApplicationDocumentsPath();
  if (settingsPath == null) {
    return;
  }
  final file = File('$settingsPath/settings');
  if (file.existsSync()) {
    file.deleteSync();
  }
}

class _FakePathProvider
    with t.Fake, MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String _documentsPath;
  final String _temporaryPath;

  _FakePathProvider()
    : _documentsPath = Directory.systemTemp
          .createTempSync('hmb_settings_test_doc_')
          .path,
      _temporaryPath = Directory.systemTemp
          .createTempSync('hmb_settings_test_tmp_')
          .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getTemporaryPath() async => _temporaryPath;
}
