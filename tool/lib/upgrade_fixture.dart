import 'package:sqlite3/sqlite3.dart';

const syntheticCustomerName = 'HMB validation synthetic customer';
const syntheticCustomerDescription =
    'Preserve this synthetic record across the release upgrade';

/// Operates only on the local copy pulled from the disposable validation AVD.
void upgradeFixture(String action, String path) {
  if (!['seed', 'verify'].contains(action)) {
    throw ArgumentError('Expected seed or verify');
  }
  // Never create an empty DB when the pull/path is wrong.
  final db = sqlite3.open(path, mode: OpenMode.readWrite);
  try {
    if (db.select('PRAGMA integrity_check').single.values.single != 'ok') {
      throw StateError('Database integrity check failed');
    }
    if (action == 'seed') {
      db.execute(
        '''
          INSERT INTO customer
          (name, description, createdDate, modifiedDate, disbarred, customerType)
          VALUES (?, ?, ?, ?, 0, 0)''',
        [
          syntheticCustomerName,
          syntheticCustomerDescription,
          '2026-01-01T00:00:00',
          '2026-01-01T00:00:00',
        ],
      );
      final checkpoint = db.select('PRAGMA wal_checkpoint(TRUNCATE)').single;
      if (checkpoint['busy'] != 0) {
        throw StateError('Synthetic database WAL checkpoint is busy');
      }
    } else {
      final rows = db.select('SELECT description FROM customer WHERE name=?', [
        syntheticCustomerName,
      ]);
      if (rows.length != 1 ||
          rows.single['description'] != syntheticCustomerDescription) {
        throw StateError(
          'Synthetic customer was lost or changed during upgrade',
        );
      }
    }
  } finally {
    db.close();
  }
}
