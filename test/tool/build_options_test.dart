import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/lib/build_options.dart';

void main() {
  test('plain command and old short flags enable all three steps', () {
    for (final args in <List<String>>[
      [],
      ['-a', '-b', '-i'],
      ['--device', 'test-device'],
      ['--no-clean'],
    ]) {
      final options = BuildOptions(args)..validate();
      expect(options.assets, isTrue);
      expect(options.build, isTrue);
      expect(options.install, isTrue);
    }
  });

  test('each step is independently disabled without disabling the others', () {
    for (final step in ['assets', 'build', 'install']) {
      final options = BuildOptions(['--no-$step'])..validate();
      expect(options.assets, step != 'assets');
      expect(options.build, step != 'build');
      expect(options.install, step != 'install');
    }
    final none = BuildOptions(['--no-assets', '--no-build', '--no-install'])
      ..validate();
    expect(none.assets || none.build || none.install, isFalse);
  });

  test('release disables device installation and respects no-assets', () {
    final options = BuildOptions(['--release', '--no-assets'])..validate();
    expect(options.release, isTrue);
    expect(options.assets, isFalse);
    expect(options.build, isTrue);
    expect(options.install, isFalse);
    expect(
      BuildOptions(['--release', '--no-build']).validate,
      throwsFormatException,
    );
  });

  test('device, baseline and clean options retain their values', () {
    final options = BuildOptions([
      '-d',
      'usb-device',
      '--previous-artifact',
      '/baseline.apk',
      '--no-clean',
    ])..validate();
    expect(options.device, 'usb-device');
    expect(options.previousArtifact, '/baseline.apk');
    expect(options.clean, isFalse);
    expect(BuildOptions(['unexpected']).validate, throwsFormatException);
  });
}
