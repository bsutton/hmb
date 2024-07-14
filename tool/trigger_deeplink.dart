#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

void main() {
  'adb shell am start -a android.intent.action.VIEW '
          '-c android.intent.category.BROWSABLE '
          '-d "https://ivanhoehandyman.com.au/xero/auth_complete"'
      .run;
}
