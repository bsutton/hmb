import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../util/hmb_theme.dart';
import 'text/hmb_text_themes.dart';

enum SurfaceElevation {
  e0(HMBColors.surface0dp),
  e1(HMBColors.surface1dp),
  e2(HMBColors.surface2dp),
  e3(HMBColors.surface3dp),
  e4(HMBColors.surface4dp),
  e6(HMBColors.surface6dp),
  e8(HMBColors.surface8dp),
  e12(HMBColors.surface12dp),
  e16(HMBColors.surface16dp),
  e24(HMBColors.surface24dp),
  ;

  const SurfaceElevation(this.color);
  final Color color;
}

///
/// Creates a Material design surface with a given [elevation].
/// The default [elevation] is 4dp, the default [padding] is
/// defined by [HMBTheme.padding].
///
/// A Surface is just a container using a defined color to give the
/// illusion of an elevation for a dark theme.
///
class Surface extends StatelessWidget {
  const Surface({
    required this.child,
    this.elevation = SurfaceElevation.e4,
    this.padding = const EdgeInsets.all(HMBTheme.padding),
    this.margin = EdgeInsets.zero,
    super.key,
  });
  final Widget child;
  final SurfaceElevation elevation;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => Container(
      padding: margin,
      child: Container(color: elevation.color, padding: padding, child: child));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<SurfaceElevation>('elevation', elevation))
      ..add(DiagnosticsProperty<EdgeInsetsGeometry?>('padding', padding));
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.title,
    required this.body,
    this.height,
    this.onPressed,
    this.elevation = SurfaceElevation.e4,
    this.padding = const EdgeInsets.all(HMBTheme.padding),
    super.key,
  });

  final String title;
  final Widget body;

  final double? height;

  final void Function()? onPressed;

  final SurfaceElevation elevation;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
            height: height,
            color: elevation.color,
            padding: padding,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [HMBTextHeadline(title), body])),
      );
}
