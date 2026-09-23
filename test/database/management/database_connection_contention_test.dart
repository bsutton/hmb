import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao_image_cache_variant.dart';
import 'package:hmb/database/factory/flutter_database_factory.dart';
import 'package:hmb/database/management/database_helper.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'db_utility_test_helper.dart';

void main() {
  setUp(setupTestDb);
  tearDown(tearDownTestDb);

  test('foreground cache reads wait for a worker write transaction', () async {
    final ready = ReceivePort();
    final writer = _startWriter(testDbPath, ready.sendPort);
    final release = await ready.first as SendPort;
    final timer = Timer(
      const Duration(milliseconds: 250),
      () => release.send(null),
    );
    try {
      expect(await DaoImageCacheVariant().totalBytes(), isNonNegative);
    } finally {
      timer.cancel();
      release.send(null);
      await writer;
      ready.close();
    }
  });

  test('transaction acquisition waits without replaying its body', () async {
    final ready = ReceivePort();
    final writer = _startWriter(testDbPath, ready.sendPort);
    final release = await ready.first as SendPort;
    final timer = Timer(
      const Duration(milliseconds: 250),
      () => release.send(null),
    );
    var calls = 0;
    try {
      await testDb!.transaction((transaction) async {
        calls++;
        await transaction.rawUpdate(
          'UPDATE job_billing_state SET checked_at = checked_at',
        );
      }, exclusive: true);
      expect(calls, 1);
    } finally {
      timer.cancel();
      release.send(null);
      await writer;
      ready.close();
    }
  });

  test('persistent contention still reports a database error', () async {
    final ready = ReceivePort();
    final writer = _startWriter(testDbPath, ready.sendPort);
    final release = await ready.first as SendPort;
    try {
      await expectLater(
        DaoImageCacheVariant().totalBytes(),
        throwsA(
          isA<DatabaseException>().having(
            (error) => error.getResultCode(),
            'SQLite code',
            5,
          ),
        ),
      ).timeout(const Duration(seconds: 15));
    } finally {
      release.send(null);
      await writer;
      ready.close();
    }
  });

  test('worker reads wait for a foreground write transaction', () async {
    final acquired = Completer<void>();
    final release = Completer<void>();
    final writer = testDb!.transaction((transaction) async {
      await transaction.rawUpdate(
        'UPDATE job_billing_state SET checked_at = checked_at',
      );
      acquired.complete();
      await release.future;
    }, exclusive: true);
    await acquired.future;
    final ready = ReceivePort();
    final reader = _startReader(testDbPath, ready.sendPort);
    // Attach an error handler before awaiting the worker's ready message.
    final result = expectLater(reader, completion(isPositive));
    await ready.first;
    final timer = Timer(const Duration(milliseconds: 250), release.complete);
    try {
      await result;
    } finally {
      timer.cancel();
      if (!release.isCompleted) {
        release.complete();
      }
      await writer;
      ready.close();
    }
  });
}

// Separate isolates give each SQLite connection its own execution thread.
// A busy connection must not block the thread that releases the write lock.
Future<void> _startWriter(String path, SendPort ready) => Isolate.run(() async {
  final factory = FlutterDatabaseFactory()
    ..initDatabaseFactory(isWeb: false, useFfiIsolate: false);
  await DatabaseHelper.instance.withOpenDatabase(factory, path, () async {
    final release = ReceivePort();
    try {
      await DatabaseHelper.instance.database.transaction((transaction) async {
        await transaction.rawUpdate(
          'UPDATE job_billing_state SET checked_at = checked_at',
        );
        ready.send(release.sendPort);
        await release.first;
      }, exclusive: true);
    } finally {
      release.close();
    }
  });
});

Future<int> _startReader(String path, SendPort ready) => Isolate.run(() async {
  final factory = FlutterDatabaseFactory()
    ..initDatabaseFactory(isWeb: false, useFfiIsolate: false);
  var count = 0;
  // Signal before opening: the SQLite factory can read schema during open.
  ready.send(null);
  await DatabaseHelper.instance.withOpenDatabase(factory, path, () async {
    final rows = await DatabaseHelper.instance.database.rawQuery(
      'SELECT COUNT(*) AS count FROM system',
    );
    count = rows.single['count']! as int;
  });
  return count;
});
