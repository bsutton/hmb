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

import 'package:flutter/widgets.dart';
import 'package:june/june.dart';

class DesktopBackGestureSuppress extends StatefulWidget {
  final Widget child;

  const DesktopBackGestureSuppress({required this.child, super.key});

  @override
  State<DesktopBackGestureSuppress> createState() =>
      _DesktopBackGestureSuppressState();
}

class _DesktopBackGestureSuppressState
    extends State<DesktopBackGestureSuppress> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        June.getState(IgnoreDesktopGesture.new).ignored = true;
      }
    });
  }

  @override
  void dispose() {
    // Defer the state update to avoid calling setState when the widget
    //tree is locked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gestureState = June.getState(IgnoreDesktopGesture.new);

      if (!gestureState.isDisposed) {
        gestureState.ignored = false;
      }
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class IgnoreDesktopGesture extends JuneState {
  var _ignored = false;

  bool get ignored => _ignored;

  set ignored(bool value) {
    _ignored = value;
    setState();
  }
}
