// --------------------
// Imports
// --------------------

import 'dart:isolate';

class BackupParams {
  BackupParams({
    required this.sendPort,
    required this.pathToZip,
    required this.pathToBackupFile,
    required this.authHeaders,
    required this.progressStageStart,
    required this.progressStageEnd,
  });
  final SendPort sendPort;
  // Path where the zip file (containing the DB backup) will be written
  final String pathToZip;
  // Path to the copied database file.
  final String pathToBackupFile;
  // Google Drive authentication headers.
  final Map<String, String> authHeaders;
  // Progress staging values for reporting.
  final int progressStageStart;
  final int progressStageEnd;
}
