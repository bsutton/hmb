import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// CLI code intentionally lives under tool/lib, outside the app package.
// ignore: avoid_relative_lib_imports
import '../../tool/lib/android_validation.dart';

void main() {
  test('real emulator welcome and dashboard hierarchies are ready', () {
    for (final screen in ['welcome', 'dashboard']) {
      final xml = File(
        'test/tool/fixtures/android_$screen.xml',
      ).readAsStringSync();
      expect(isHmbReady(xml), isTrue);
    }
  });
  test('a process or splash screen is not startup readiness', () {
    expect(isHmbReady('Status: ok'), isFalse);
    expect(
      isHmbReady('<node package="dev.onepub.handyman" text="Loading"/>'),
      isFalse,
    );
    expect(
      isHmbReady('<node package="another.app" text="Dashboard Jobs Backup"/>'),
      isFalse,
    );
    expect(
      isHmbReady(
        '<node package="dev.onepub.handyman" '
        'text="Welcome to Hold My Beer (HMB) Next"/>',
      ),
      isTrue,
    );
    expect(
      isHmbReady(
        '<node package="dev.onepub.handyman" text="Dashboard Jobs Backup"/>',
      ),
      isTrue,
    );
  });

  test('readiness excludes a system overlay', () {
    expect(
      isHmbForeground(
        'mCurrentFocus=Window{dev.onepub.handyman/.MainActivity}',
      ),
      isTrue,
    );
    expect(
      isHmbForeground(
        'mCurrentFocus=Window{com.android.permissioncontroller/Dialog}',
      ),
      isFalse,
    );
  });

  test('Java, native, Dart crashes and ANRs fail the startup gate', () {
    for (final log in [
      'FATAL EXCEPTION: main',
      'Fatal signal 11',
      'Unhandled Exception: startup failed',
      'ANR in dev.onepub.handyman',
    ]) {
      expect(hasFatalStartupLog(log), isTrue);
    }
    expect(hasFatalStartupLog('Activity started; normal lifecycle'), isFalse);
  });

  test(
    'missing baseline and mixed artifact types fail before device access',
    () {
      final temp = Directory.systemTemp.createTempSync('hmb-gate-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final missing = AndroidValidation(
        previousArtifact: '${temp.path}/missing.apk',
        sdk: temp.path,
      );
      expect(() => missing.preflight('candidate.apk'), throwsStateError);
      final previous = File('${temp.path}/previous.apk')
        ..writeAsStringSync('placeholder');
      final gate = AndroidValidation(
        previousArtifact: previous.path,
        sdk: temp.path,
      );
      expect(() => gate.preflight('candidate.aab'), throwsStateError);
      expect(() => gate.preflight('candidate.apk'), throwsStateError);
    },
  );
}
