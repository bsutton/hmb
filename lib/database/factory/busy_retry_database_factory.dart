import 'package:sqflite_common/sqlite_api.dart';
// Preserve sqflite's concrete database and transaction types through its
// driver invocation hook.
// ignore: implementation_imports
import 'package:sqflite_common/src/mixin/factory.dart';

/// Adds an asynchronous, elapsed-time retry to SQLite's native timeout.
/// On desktop, profiler signals can interrupt the native busy handler's sleeps.
DatabaseFactory busyRetryDatabaseFactory(
  DatabaseFactory factory,
) => buildDatabaseFactory(
  invokeMethod: (method, [arguments]) async {
    final driver = factory as SqfliteInvokeHandler;
    final retryable =
        arguments is Map &&
        arguments['transactionId'] == null &&
        (method == 'query' ||
            (method == 'execute' && arguments['inTransaction'] == true));
    final elapsed = Stopwatch()..start();
    while (true) {
      try {
        return await driver.invokeMethod<Object?>(method, arguments);
      } on DatabaseException catch (error) {
        // Retry autocommit reads and acquiring a transaction. Never replay a
        // transaction body, a write, or a partly executed batch.
        if (!retryable ||
            error.getResultCode() != 5 ||
            elapsed.elapsed >= const Duration(seconds: 5)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
  },
);
