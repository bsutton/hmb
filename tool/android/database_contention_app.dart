// Standalone Flutter regression app. Run on a disposable Android emulator:
// flutter run -d <emulator> -t tool/android/database_contention_app.dart
// This uses only a synthetic temporary database, never the HMB database.
import 'dart:async';
import 'dart:io';

import 'package:hmb/database/factory/flutter_database_factory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Result('Running database contention check'));
  try {
    await _checkContention();
    print('DATABASE_CONTENTION_PASS');
    runApp(const _Result('DATABASE_CONTENTION_PASS'));
  } catch (error, stack) {
    print('DATABASE_CONTENTION_FAIL: $error\n$stack');
    runApp(const _Result('DATABASE_CONTENTION_FAIL'));
    rethrow;
  }
}

class _Result extends StatelessWidget {
  final String message;
  const _Result(this.message);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text(message))),
  );
}

Future<void> _checkContention() async {
  final directory = Directory(
    path.join((await getTemporaryDirectory()).path, 'contention-test'),
  )..createSync(recursive: true);
  final databasePath = path.join(directory.path, 'synthetic.db');
  final factory = FlutterDatabaseFactory();
  final writer = await factory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA busy_timeout = 5000');
      },
    ),
  );
  await writer.execute('CREATE TABLE IF NOT EXISTS sample(value INTEGER)');
  await writer.delete('sample');
  await writer.insert('sample', {'value': 1});
  final reader = await factory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  final locked = Completer<void>();
  final release = Completer<void>();
  final writing = writer.transaction((txn) async {
    await txn.update('sample', {'value': 2});
    locked.complete();
    await release.future;
  }, exclusive: true);
  await locked.future;
  final timer = Timer(const Duration(milliseconds: 150), release.complete);
  try {
    final rows = await reader
        .query('sample')
        .timeout(const Duration(seconds: 3));
    if (rows.single['value'] != 2) {
      throw StateError('Reader did not observe the committed value.');
    }
    await writing;
  } finally {
    timer.cancel();
    if (!release.isCompleted) {
      release.complete();
    }
    await writing;
    await reader.close();
    await writer.close();
    directory.deleteSync(recursive: true);
  }
}
