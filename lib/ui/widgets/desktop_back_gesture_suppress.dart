import 'package:flutter/widgets.dart';
import 'package:june/june.dart';

class DesktopBackGestureSuppress extends StatefulWidget {
  const DesktopBackGestureSuppress({required this.child, super.key});

  final Widget child;

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
        June.getState(IgnoreDesktopGesture.new)
          ..ignored = true
          ..setState();
      }
    });
  }

  @override
  void dispose() {
    // Defer the state update to avoid calling setState when the widget tree is locked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gestureState = June.getState(IgnoreDesktopGesture.new);

      if (!gestureState.isDisposed) {
        gestureState
          ..ignored = false
          ..setState();
      }
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class IgnoreDesktopGesture extends JuneState {
  bool ignored = false;
}
