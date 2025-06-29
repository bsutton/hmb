/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/widgets/hmb_toast.dart';

Future<void> clipboardCopyTo(BuildContext context, String data) async {
  await Clipboard.setData(ClipboardData(text: data));

  if (context.mounted) {
    HMBToast.info('Copy $data to the clipboard');
  }
}
