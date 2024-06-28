import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/hmb_toast.dart';

Future<void> clipboardCopyTo(BuildContext context, String data) async {
  await Clipboard.setData(ClipboardData(text: data));

  if (context.mounted) {
    HMBToast.notice(context, 'Copy $data to the clipboard');
  }
}
