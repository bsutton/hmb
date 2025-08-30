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

import 'dart:io';

import 'package:flutter/material.dart';

/// Call this method in your initState method of your [StatefulWidget
/// to set the focus to a focusable widget.
/// This should normally be the first widget on the screen.
void focusFirst(BuildContext context, FocusNode node) {
  // we don't set focus on mobile as it opens the
  // keyboard which is somewhat annoying - I think.
  if (!(Platform.isAndroid || Platform.isIOS)) {
    /// Set focus after the page finishes loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(node);
    });
  }
}
