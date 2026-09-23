import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/cache/hmb_image_cache.dart';
import 'package:hmb/util/dart/log.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../database/management/db_utility_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Log.configure(Directory.current.path);

  test(
    'failed startup trimming does not escape as an unhandled error',
    () async {
      await setupTestDb();
      addTearDown(tearDownTestDb);
      final directory = await Directory.systemTemp.createTemp(
        'hmb_trim_start_',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPath(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previous;
        await directory.delete(recursive: true);
      });
      // Model a failed cache query without waiting for a real lock timeout.
      await testDb!.execute('DROP TABLE image_cache_variant');
      final errors = <Object>[];
      await runZonedGuarded<Future<void>>(() async {
        await HMBImageCache().init(
          (_, _) async {},
          (_) async => CompressResult(null, success: false),
        );
        // Drain the connection after the fire-and-forget trim query.
        await testDb!.rawQuery('SELECT 1');
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => errors.add(error));
      expect(errors, isEmpty);
    },
  );
}

class _TemporaryPath extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  _TemporaryPath(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;
}
