import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/lib/apk_components.dart';

void main() {
  const prefix =
      '<manifest '
      'xmlns:a="http://schemas.android.com/apk/res/android" package="dev.test">';
  test('missing provider, alias target and disabled metadata service', () {
    const manifest =
        '$prefix<application> '
        '<provider a:name=".Provider"/> '
        '<activity-alias a:name=".Alias" a:targetActivity=".Activity"/> '
        '<service a:name=".Metadata" a:enabled="false"/> '
        '</application></manifest>';
    expect(missingComponents(manifest, 'C d 1 1 1 dev.test.Activity'), [
      'Missing provider class: dev.test.Provider',
    ]);
    expect(missingComponents(manifest, 'C d 1 1 1 dev.test.Provider'), [
      'Missing targetActivity class: dev.test.Activity',
    ]);
    expect(
      missingComponents(
        manifest,
        'C d 1 1 1 dev.test.Activity\nC d 1 1 1 dev.test.Provider',
      ),
      isEmpty,
    );
  });
  test('application factory and relative names checked; platform exempt', () {
    const manifest =
        '$prefix<application a:name="App" '
        'a:appComponentFactory="dev.test.Factory"> '
        '<activity a:name="android.app.Activity"/> '
        '</application></manifest>';
    expect(missingComponents(manifest, 'C d 1 1 1 dev.test.App'), [
      'Missing appComponentFactory class: dev.test.Factory',
    ]);
  });
  test('empty definitions, malformed XML and missing application fail', () {
    expect(() => missingComponents('<manifest/>', ''), throwsStateError);
    expect(() => missingComponents('<bad', 'C d 1 1 1 X'), throwsException);
    expect(
      () => missingComponents('<manifest/>', 'C d 1 1 1 X'),
      throwsStateError,
    );
  });
}
