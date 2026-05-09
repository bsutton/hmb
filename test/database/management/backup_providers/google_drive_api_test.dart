/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/database/management/backup_providers/google_drive/google_drive_api.dart';

void main() {
  group('Google Drive query escaping', () {
    test('escapes apostrophes and backslashes in string literals', () {
      expect(
        escapeDriveQueryLiteral(r"Brett's \ photos"),
        r"Brett\'s \\ photos",
      );
    });
  });
}
