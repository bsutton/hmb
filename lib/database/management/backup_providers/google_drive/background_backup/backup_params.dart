/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

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
