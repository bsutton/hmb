import 'package:flutter/widgets.dart';
import 'package:june/june.dart';

class SuppressDesktopBackGesture extends StatefulWidget {
  const SuppressDesktopBackGesture({required this.child, super.key});

  final Widget child;

  @override
  State<SuppressDesktopBackGesture> createState() =>
      _SuppressDesktopBackGestureState();
}

class _SuppressDesktopBackGestureState
    extends State<SuppressDesktopBackGesture> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        June.getState(IgnoreDesktopGesture.new)
          ..ignored = true
          ..setState();
      });
    });
  }

  @override
  void dispose() {
    June.getState(IgnoreDesktopGesture.new)
      ..ignored = false
      ..setState();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class IgnoreDesktopGesture extends JuneState {
  // ignore: type_annotate_public_apis
  var ignored = false;
}
