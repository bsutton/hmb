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

import 'package:pdf/widgets.dart' as pw;

class PdfPageBandLayout {
  static const bandHeight = 28.0;

  static pw.Widget continuationPageHeader() => pw.SizedBox(height: bandHeight);

  static pw.Widget pageFooter() => pw.SizedBox(height: bandHeight);
}
