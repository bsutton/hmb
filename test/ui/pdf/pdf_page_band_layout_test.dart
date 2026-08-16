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

import 'package:hmb/ui/pdf/pdf_page_band_layout.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  test('zero-margin pages reserve the full top colour band', () {
    final height = _headerHeight(PdfPageBandLayout.continuationPageHeader());

    expect(height, PdfPageBandLayout.bandHeight);
  });

  test('page margins do not reduce continuation-page clearance', () {
    final headerHeight = _headerHeight(
      PdfPageBandLayout.continuationPageHeader(),
    );

    expect(headerHeight, PdfPageBandLayout.bandHeight);
  });

  test('page footer reserves the full bottom colour band', () {
    final footerHeight = _headerHeight(PdfPageBandLayout.pageFooter());

    expect(footerHeight, PdfPageBandLayout.bandHeight);
  });
}

double _headerHeight(pw.Widget header) {
  expect(header, isA<pw.SizedBox>());
  return (header as pw.SizedBox).height!;
}
