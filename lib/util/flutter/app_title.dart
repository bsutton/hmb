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

import 'package:june/june.dart';

import '../../entity/job.dart';
import '../../src/appname.dart';

class HMBTitle extends JuneState {
  String _title = appName;

  String get title => _title;

  set title(String value) {
    _title = value;
    setState();
  }
}

void setAppTitle(String pageTitle) {
  /// Replace the top windows title with the current
  /// cruds title.
  /// We use a future as we are called during a build
  /// so can't call setState.
  Future.delayed(Duration.zero, () {
    final currentTitle = June.getState(HMBTitle.new);
    if (currentTitle.title != pageTitle) {
      June.getState(HMBTitle.new).title = pageTitle;
    }
  });
}

String formatAppTitle(String pageTitle, {Job? activeJob}) {
  if (activeJob == null) {
    return pageTitle;
  }
  return '$pageTitle [#${activeJob.id}]';
}
