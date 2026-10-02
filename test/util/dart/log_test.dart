import 'package:hmb/util/dart/log.dart';
import 'package:test/test.dart';

void main() {
  test('logging before application configuration is safe', () {
    expect(() => Log.w('An operation is still running'), returnsNormally);
    expect(() => Log.e('An operation failed'), returnsNormally);
    Log.configure('.');
    expect(() => Log.i('Application configured'), returnsNormally);
  });
}
