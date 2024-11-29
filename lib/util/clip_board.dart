import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/widgets/hmb_toast.dart';

Future<void> clipboardCopyTo(BuildContext context, String data) async {
  await Clipboard.setData(ClipboardData(text: data));

  if (context.mounted) {
    HMBToast.info('Copy $data to the clipboard');
  }
}
