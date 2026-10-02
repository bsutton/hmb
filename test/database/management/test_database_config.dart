import 'package:sqflite_common/sqlite_api.dart';

/// Disposable fixtures test SQL behavior, not recovery after a power failure.
/// Retain transactions and rollback journals without forcing a physical disk
/// sync for each small write across parallel test processes.
Future<void> configureDisposableTestDatabase(Database db) =>
    db.execute('PRAGMA synchronous = OFF');
