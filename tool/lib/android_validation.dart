import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const hmbAndroidPackage = 'dev.onepub.handyman';
const validationImage = 'system-images;android-35;default;x86_64';

/// Uses only a newly-created AVD; never selects an attached user device.
class AndroidValidation {
  AndroidValidation({required this.previousArtifact, String? sdk})
    : sdk =
          sdk ??
          Platform.environment['ANDROID_HOME'] ??
          Platform.environment['ANDROID_SDK_ROOT'] ??
          _sdkFromProperties();

  final String previousArtifact;
  final String sdk;
  late Directory _scratch;
  late Map<String, String> _environment;
  late String _serial;
  Process? _emulator;
  IOSink? _emulatorLog;
  final _commands = <String>[];

  static String _sdkFromProperties() {
    final properties = File('android/local.properties');
    if (properties.existsSync()) {
      for (final line in properties.readAsLinesSync()) {
        if (line.startsWith('sdk.dir=')) {
          return line.substring(8);
        }
      }
    }
    throw StateError('Set ANDROID_HOME to an installed Android SDK.');
  }

  String get _adb => p.join(sdk, 'platform-tools', 'adb');
  String get _analyzer =>
      p.join(sdk, 'cmdline-tools', 'latest', 'bin', 'apkanalyzer');

  void preflight(String artifact) {
    if (!File(previousArtifact).existsSync()) {
      throw StateError(
        'A known-good previous APK/AAB is required: $previousArtifact',
      );
    }
    if (!['.apk', '.aab'].contains(p.extension(artifact)) ||
        p.extension(artifact) != p.extension(previousArtifact)) {
      throw StateError(
        'Candidate and previous artifact must both be APKs or both AABs.',
      );
    }
    for (final executable in [
      _adb,
      _analyzer,
      p.join(sdk, 'emulator', 'emulator'),
      p.join(sdk, 'cmdline-tools', 'latest', 'bin', 'avdmanager'),
    ]) {
      if (!File(executable).existsSync()) {
        throw StateError('Missing $executable');
      }
    }
    if (!File(
      p.join(
        sdk,
        'system-images',
        'android-35',
        'default',
        'x86_64',
        'system.img',
      ),
    ).existsSync()) {
      throw StateError(
        'Install $validationImage with sdkmanager before building.',
      );
    }
    if (artifact.endsWith('.aab') &&
        !File(Platform.environment['BUNDLETOOL_JAR'] ?? '').existsSync()) {
      throw StateError(
        'Set BUNDLETOOL_JAR to the official bundletool JAR for AAB validation.',
      );
    }
  }

  Future<String> _run(
    String executable,
    List<String> args, {
    Duration timeout = const Duration(minutes: 2),
    bool allowFailure = false,
    String? input,
  }) async {
    _commands.add('$executable ${args.join(' ')}');
    final process = await Process.start(
      executable,
      args,
      environment: _environment,
    );
    final out = process.stdout.transform(utf8.decoder).join();
    final err = process.stderr.transform(utf8.decoder).join();
    if (input != null) {
      process.stdin.write(input);
    }
    await process.stdin.close();
    int code;
    try {
      code = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw StateError('Timed out: $executable ${args.join(' ')}');
    }
    final output = await out;
    final errors = await err;
    if (code != 0 && !allowFailure) {
      throw ProcessException(executable, args, '$output\n$errors', code);
    }
    return output.trim();
  }

  Future<String> _device(List<String> args, {bool allowFailure = false}) =>
      _run(_adb, ['-s', _serial, ...args], allowFailure: allowFailure);

  Future<void> validate(String artifact) async {
    preflight(artifact);
    if (!File(artifact).existsSync()) {
      throw StateError('Missing candidate: $artifact');
    }
    _scratch = Directory(
      p.join(
        'build',
        'android-validation',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    )..createSync(recursive: true);
    _scratch = Directory(_scratch.absolute.path);
    final avds = Directory(p.join(_scratch.path, 'avd'))..createSync();
    _environment = {...Platform.environment, 'ANDROID_AVD_HOME': avds.path};
    try {
      await _startEmulator();
      final candidate = await _prepare(artifact, 'candidate');
      final previous = await _prepare(previousArtifact, 'previous');
      await _assertVersionOrder(previous.first, candidate.first);
      await _install(candidate, replace: false);
      await _coldStart('fresh');
      await _device(['uninstall', hmbAndroidPackage]);
      await _install(previous, replace: false);
      await _coldStart('previous');
      await _database('seed', 'before-upgrade');
      await _install(candidate, replace: true);
      await _coldStart('upgrade');
      await _database('verify', 'after-upgrade');
      File(p.join(_scratch.path, 'PASS.txt')).writeAsStringSync(
        'Fresh release startup and same-signature upgrade passed.\n'
        'Candidate: ${File(artifact).absolute.path}\n'
        'Previous: ${File(previousArtifact).absolute.path}\n',
      );
      stdout.writeln('Android validation PASSED: ${_scratch.path}');
    } finally {
      File(
        p.join(_scratch.path, 'commands.log'),
      ).writeAsStringSync(_commands.join('\n'));
      // Only terminate the process this invocation created; never a user AVD.
      _emulator?.kill();
      if (_emulator != null) {
        try {
          await _emulator!.exitCode.timeout(const Duration(seconds: 10));
        } on TimeoutException {
          _emulator!.kill(ProcessSignal.sigkill);
        }
      }
      await _emulatorLog?.flush();
      await _emulatorLog?.close();
      // Keep logs and synthetic DBs; discard the multi-GB AVD userdata.
      if (avds.existsSync()) {
        avds.deleteSync(recursive: true);
      }
    }
  }

  Future<void> _startEmulator() async {
    var port = 5554;
    final attached = await _run(_adb, ['devices']);
    for (; port < 5680; port += 2) {
      if (attached.contains('emulator-$port')) {
        continue;
      }
      ServerSocket? console;
      ServerSocket? bridge;
      try {
        console = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        bridge = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port + 1,
        );
        break;
      } on SocketException {
        continue;
      } finally {
        await console?.close();
        await bridge?.close();
      }
    }
    if (port >= 5680) {
      throw StateError('No free emulator port.');
    }
    _serial = 'emulator-$port';
    final name = 'hmb-validation-${DateTime.now().microsecondsSinceEpoch}';
    await _run(p.join(sdk, 'cmdline-tools', 'latest', 'bin', 'avdmanager'), [
      'create',
      'avd',
      '--name',
      name,
      '--package',
      validationImage,
    ], input: 'no\n');
    _emulatorLog = File(p.join(_scratch.path, 'emulator.log')).openWrite();
    _emulator = await Process.start(p.join(sdk, 'emulator', 'emulator'), [
      '-avd',
      name,
      '-port',
      '$port',
      '-no-window',
      '-no-audio',
      '-no-snapshot',
      '-gpu',
      'swiftshader_indirect',
      '-no-boot-anim',
    ], environment: _environment);
    _emulator!.stdout.listen(_emulatorLog!.add);
    _emulator!.stderr.listen(_emulatorLog!.add);
    await _until(
      () async =>
          (await _device([
            'shell',
            'getprop',
            'sys.boot_completed',
          ], allowFailure: true)).trim() ==
          '1',
      const Duration(minutes: 4),
      'emulator boot',
    );
    final actualName = await _device(['emu', 'avd', 'name']);
    if (actualName.split('\n').first.trim() != name) {
      throw StateError(
        'Emulator identity mismatch; refusing device operations.',
      );
    }
    await _device(['root']);
    await _device(['wait-for-device']);
    if ((await _device(['shell', 'id', '-u'])).trim() != '0') {
      throw StateError('Validation needs the rootable AOSP system image.');
    }
    await _device(['shell', 'input', 'keyevent', '82']);
  }

  Future<List<String>> _prepare(String artifact, String label) async {
    if (artifact.endsWith('.apk')) {
      await _check([artifact]);
      return [File(artifact).absolute.path];
    }
    // Bundle-derived APKs use a disposable test key.
    final key = p.join(_scratch.path, 'validation.jks');
    if (!File(key).existsSync()) {
      await _run('keytool', [
        '-genkeypair',
        '-keystore',
        key,
        '-storepass',
        'android',
        '-keypass',
        'android',
        '-alias',
        'validation',
        '-dname',
        'CN=HMB validation',
        '-keyalg',
        'RSA',
        '-validity',
        '2',
      ]);
    }
    final bundletool = Platform.environment['BUNDLETOOL_JAR']!;
    final universal = p.join(_scratch.path, '$label-universal.apks');
    final splitSet = p.join(_scratch.path, '$label-splits.apks');
    final common = [
      '-jar',
      bundletool,
      'build-apks',
      '--bundle=${File(artifact).absolute.path}',
      '--ks=$key',
      '--ks-pass=pass:android',
      '--key-pass=pass:android',
      '--ks-key-alias=validation',
    ];
    await _run('java', [...common, '--mode=universal', '--output=$universal']);
    final universalDir = p.join(_scratch.path, '$label-universal');
    await _run('unzip', ['-q', universal, '-d', universalDir]);
    await _check([p.join(universalDir, 'universal.apk')]);
    await _run('java', [
      ...common,
      '--connected-device',
      '--device-id=$_serial',
      '--adb=$_adb',
      '--output=$splitSet',
    ]);
    final spec = p.join(_scratch.path, '$label-device.json');
    await _run('java', [
      '-jar',
      bundletool,
      'get-device-spec',
      '--device-id=$_serial',
      '--adb=$_adb',
      '--output=$spec',
    ]);
    final splitDir = p.join(_scratch.path, '$label-splits');
    await _run('java', [
      '-jar',
      bundletool,
      'extract-apks',
      '--apks=$splitSet',
      '--device-spec=$spec',
      '--output-dir=$splitDir',
    ]);
    final apks = Directory(splitDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.apk'))
        .map((file) => file.path)
        .toList();
    if (apks.isEmpty) {
      throw StateError('bundletool produced no device APKs.');
    }
    // Inspect the base version; include every code split in class checks.
    apks.sort(
      (a, b) => (a.contains('base-master') ? '' : a).compareTo(
        b.contains('base-master') ? '' : b,
      ),
    );
    await _check(apks);
    return apks;
  }

  Future<void> _check(List<String> apks) async {
    await _run('python3', [
      'tool/android/check_apk_components.py',
      '--apkanalyzer',
      _analyzer,
      ...apks,
    ]);
  }

  Future<void> _assertVersionOrder(String previous, String candidate) async {
    final oldCode = int.parse(
      await _run(_analyzer, ['manifest', 'version-code', previous]),
    );
    final newCode = int.parse(
      await _run(_analyzer, ['manifest', 'version-code', candidate]),
    );
    if (oldCode >= newCode) {
      throw StateError(
        'Previous artifact must have a lower versionCode '
        '($oldCode >= $newCode).',
      );
    }
  }

  Future<void> _install(List<String> apks, {required bool replace}) async {
    final id = await _run(_analyzer, [
      'manifest',
      'application-id',
      apks.first,
    ]);
    if (id != hmbAndroidPackage) {
      throw StateError('Unexpected package: $id');
    }
    await _device([
      if (apks.length == 1) 'install' else 'install-multiple',
      if (replace) '-r',
      ...apks,
    ]);
    // Root-owned firewall rule blocks all networking by this synthetic app UID.
    final listing = await _device([
      'shell',
      'cmd',
      'package',
      'list',
      'packages',
      '-U',
      hmbAndroidPackage,
    ]);
    final uid = RegExp(r'uid:(\d+)').firstMatch(listing)?.group(1);
    if (uid == null) {
      throw StateError('Cannot determine app UID for network isolation.');
    }
    for (final firewall in ['iptables', 'ip6tables']) {
      await _device([
        'shell',
        firewall,
        '-A',
        'OUTPUT',
        '-m',
        'owner',
        '--uid-owner',
        uid,
        '-j',
        'REJECT',
      ]);
    }
    await _device([
      'shell',
      'pm',
      'grant',
      hmbAndroidPackage,
      'android.permission.POST_NOTIFICATIONS',
    ]);
  }

  Future<void> _coldStart(String label) async {
    await _device(['shell', 'am', 'force-stop', hmbAndroidPackage]);
    await _device(['logcat', '-c']); // This newly-owned emulator only.
    await _device([
      'shell',
      'am',
      'start',
      '-W',
      '-n',
      '$hmbAndroidPackage/.MainActivity',
    ]);
    await _until(
      () async {
        await _checkCrashes(label);
        await _device(['shell', 'rm', '-f', '/data/local/tmp/hmb-window.xml']);
        await _device([
          'shell',
          'uiautomator',
          'dump',
          '/data/local/tmp/hmb-window.xml',
        ], allowFailure: true);
        final xml = await _device([
          'shell',
          'cat',
          '/data/local/tmp/hmb-window.xml',
        ], allowFailure: true);
        File(p.join(_scratch.path, '$label-window.xml')).writeAsStringSync(xml);
        final window = await _device(['shell', 'dumpsys', 'window']);
        File(
          p.join(_scratch.path, '$label-focus.txt'),
        ).writeAsStringSync(window);
        return isHmbReady(xml) && isHmbForeground(window);
      },
      const Duration(seconds: 90),
      '$label startup readiness',
    );
    // Observe after first rendered screen, not merely successful am start.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _checkCrashes(label);
      if ((await _device([
        'shell',
        'pidof',
        hmbAndroidPackage,
      ], allowFailure: true)).isEmpty) {
        throw StateError('$label: app exited after readiness');
      }
    }
  }

  Future<void> _checkCrashes(String label) async {
    final logs = await _device(['logcat', '-d', '-v', 'threadtime']);
    File(p.join(_scratch.path, '$label-logcat.txt')).writeAsStringSync(logs);
    if (hasFatalStartupLog(logs)) {
      throw StateError('$label: fatal startup log; see ${_scratch.path}');
    }
  }

  Future<void> _database(String action, String label) async {
    await _device(['shell', 'am', 'force-stop', hmbAndroidPackage]);
    const remoteDir = '/data/user/0/$hmbAndroidPackage/app_flutter';
    final local = Directory(p.join(_scratch.path, label))..createSync();
    await _device(['pull', '$remoteDir/handyman.db', local.path]);
    for (final suffix in ['-wal', '-shm']) {
      final exists = await _device([
        'shell',
        'test',
        '-f',
        '$remoteDir/handyman.db$suffix',
        '&&',
        'echo',
        'yes',
      ], allowFailure: true);
      if (exists == 'yes') {
        await _device(['pull', '$remoteDir/handyman.db$suffix', local.path]);
      }
    }
    await _run('python3', [
      'tool/android/upgrade_fixture.py',
      action,
      p.join(local.path, 'handyman.db'),
    ]);
    if (action == 'seed') {
      await _device([
        'push',
        p.join(local.path, 'handyman.db'),
        '/data/local/tmp/hmb-seeded.db',
      ]);
      // cat into the existing file preserves app ownership and SELinux context.
      await _device([
        'shell',
        'cat',
        '/data/local/tmp/hmb-seeded.db',
        '>',
        '$remoteDir/handyman.db',
      ]);
      await _device([
        'shell',
        'rm',
        '-f',
        '$remoteDir/handyman.db-wal',
        '$remoteDir/handyman.db-shm',
      ]);
    }
  }

  Future<void> _until(
    Future<bool> Function() ready,
    Duration timeout,
    String label,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await ready()) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('Timed out waiting for $label; see ${_scratch.path}');
  }
}

bool isHmbReady(String xml) =>
    xml.contains('package="$hmbAndroidPackage"') &&
    ((xml.contains('Welcome to Hold My Beer (HMB)') && xml.contains('Next')) ||
        (xml.contains('Dashboard') &&
            xml.contains('Jobs') &&
            xml.contains('Backup')));

bool hasFatalStartupLog(String log) =>
    log.contains('FATAL EXCEPTION') ||
    log.contains('Fatal signal') ||
    log.contains('Unhandled Exception') ||
    log.contains('ANR in $hmbAndroidPackage');

/// Require the app window itself, not a system dialog over its hierarchy.
bool isHmbForeground(String windows) =>
    RegExp(r'mCurrentFocus=.*dev\.onepub\.handyman/').hasMatch(windows);
