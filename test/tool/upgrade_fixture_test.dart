import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// ignore: avoid_relative_lib_imports
import '../../tool/lib/upgrade_fixture.dart';

void main() {
  test('fixture detects changed and lost data after WAL checkpoint', () {
    final temp = Directory.systemTemp.createTempSync('hmb-fixture-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = '${temp.path}/handyman.db';
    sqlite3.open(path)
      ..execute('PRAGMA journal_mode=WAL')
      ..execute(
        'CREATE TABLE customer '
        '(name, description, createdDate, modifiedDate, '
        'disbarred, customerType)',
      )
      ..close();
    upgradeFixture('seed', path);
    upgradeFixture('verify', path);
    final changed = sqlite3.open(path)
      ..execute("UPDATE customer SET description='changed'");
    expect(() => upgradeFixture('verify', path), throwsStateError);
    changed.execute('DELETE FROM customer');
    expect(() => upgradeFixture('verify', path), throwsStateError);
    changed.close();
  });
  test('bad action or absent database cannot create a database', () {
    final temp = Directory.systemTemp.createTempSync('hmb-fixture-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = '${temp.path}/missing.db';
    expect(() => upgradeFixture('drop', path), throwsArgumentError);
    expect(() => upgradeFixture('seed', path), throwsA(isA<SqliteException>()));
    expect(File(path).existsSync(), isFalse);
  });
}
