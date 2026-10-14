import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/lib/android_validation.dart';
// ignore: avoid_relative_lib_imports
import '../../tool/lib/build_artifact_cache.dart';

void main() {
  late Directory project;
  late Directory outputs;
  late BuildArtifactCache cache;

  setUp(() {
    project = Directory.systemTemp.createTempSync('hmb-build-cache-');
    outputs = Directory('${project.path}/build')..createSync();
    cache = BuildArtifactCache(directory: '${project.path}/.android-artifacts');
  });
  tearDown(() => project.deleteSync(recursive: true));

  File candidate(String bytes, {String extension = '.apk'}) =>
      File('${outputs.path}/app-release$extension')..writeAsStringSync(bytes);

  test('bootstrap survives cleaning and failed build retries', () async {
    final old = candidate('previous build');
    final path = old.path;
    final previous = await cache.resolvePrevious(
      candidatePath: path,
      building: true,
    );
    outputs.deleteSync(recursive: true);
    expect(File(previous).readAsStringSync(), 'previous build');
    outputs.createSync();
    candidate('failed new build');
    expect(
      await cache.resolvePrevious(candidatePath: path, building: true),
      previous,
    );
    expect(
      File('${cache.directory.path}/validated.apk.json').existsSync(),
      isFalse,
    );
  });

  test(
    'validated builds advance baseline while reinstall uses predecessor',
    () async {
      final apk = candidate('old');
      final previous = await cache.resolvePrevious(
        candidatePath: apk.path,
        building: true,
      );
      apk.writeAsStringSync('passed candidate');
      await cache.recordValidated(
        candidate: await ValidatedArtifact.capture(apk.path),
        previousPath: previous,
      );
      final latest = await cache.resolvePrevious(
        candidatePath: apk.path,
        building: true,
      );
      expect(File(latest).readAsStringSync(), 'passed candidate');
      expect(
        await cache.resolvePrevious(candidatePath: apk.path, building: false),
        previous,
      );
      apk.writeAsStringSync('not yet validated');
      expect(
        await cache.resolvePrevious(candidatePath: apk.path, building: false),
        latest,
      );
    },
  );

  test('changed candidate cannot advance last validated artifact', () async {
    final apk = candidate('old');
    final previous = await cache.resolvePrevious(
      candidatePath: apk.path,
      building: true,
    );
    apk.writeAsStringSync('validated');
    final receipt = await ValidatedArtifact.capture(apk.path);
    apk.writeAsStringSync('changed after validation');
    await expectLater(
      cache.recordValidated(candidate: receipt, previousPath: previous),
      throwsStateError,
    );
    expect(
      await cache.resolvePrevious(candidatePath: apk.path, building: true),
      previous,
    );
  });

  test(
    'install reuses validation only for the recorded, unchanged APK',
    () async {
      final apk = candidate('old');
      expect(await cache.validatedCandidate(apk.path), isNull);
      final previous = await cache.resolvePrevious(
        candidatePath: apk.path,
        building: true,
      );
      // Merely preserving a build is not evidence of successful validation.
      expect(await cache.validatedCandidate(apk.path), isNull);
      apk.writeAsStringSync('passed candidate');
      await cache.recordValidated(
        candidate: await ValidatedArtifact.capture(apk.path),
        previousPath: previous,
      );
      final receipt = await cache.validatedCandidate(apk.path);
      expect(receipt, isNotNull);
      await receipt!.assertUnchanged();
      apk.writeAsStringSync('different candidate');
      expect(await cache.validatedCandidate(apk.path), isNull);
      await expectLater(receipt.assertUnchanged(), throwsStateError);
      apk.deleteSync();
      expect(await cache.validatedCandidate(apk.path), isNull);
    },
  );

  test(
    'explicit baseline inside build survives clean and overrides cache',
    () async {
      final apk = candidate('default');
      await cache.resolvePrevious(candidatePath: apk.path, building: true);
      final explicit = File('${outputs.path}/chosen.apk')
        ..writeAsStringSync('chosen baseline');
      final selected = await cache.resolvePrevious(
        candidatePath: apk.path,
        building: true,
        explicitPath: explicit.path,
      );
      outputs.deleteSync(recursive: true);
      expect(File(selected).readAsStringSync(), 'chosen baseline');
    },
  );

  test('APK and AAB baselines both survive a clean', () async {
    final apk = candidate('APK');
    final aab = candidate('AAB', extension: '.aab');
    await cache.preserveExistingOutput(apk.path);
    await cache.preserveExistingOutput(aab.path);
    outputs.deleteSync(recursive: true);
    for (final artifact in [apk, aab]) {
      final preserved = await cache.resolvePrevious(
        candidatePath: artifact.path,
        building: true,
      );
      expect(
        File(preserved).readAsStringSync(),
        artifact == apk ? 'APK' : 'AAB',
      );
    }
  });

  test(
    'missing, mixed-type, and same-candidate baselines fail safely',
    () async {
      await expectLater(
        cache.resolvePrevious(
          candidatePath: '${outputs.path}/missing.apk',
          building: true,
        ),
        throwsStateError,
      );
      final apk = candidate('only artifact');
      await expectLater(
        cache.resolvePrevious(candidatePath: apk.path, building: false),
        throwsStateError,
      );
      await cache.resolvePrevious(candidatePath: apk.path, building: true);
      await expectLater(
        cache.resolvePrevious(candidatePath: apk.path, building: false),
        throwsStateError,
      );
      await expectLater(
        cache.resolvePrevious(
          candidatePath: apk.path,
          building: true,
          explicitPath: candidate('bundle', extension: '.aab').path,
        ),
        throwsStateError,
      );
    },
  );

  test('corrupted baseline is rejected instead of silently replaced', () async {
    final apk = candidate('old');
    final previous = await cache.resolvePrevious(
      candidatePath: apk.path,
      building: true,
    );
    File(previous).writeAsStringSync('corrupted');
    await expectLater(
      cache.resolvePrevious(candidatePath: apk.path, building: true),
      throwsStateError,
    );
  });
}
