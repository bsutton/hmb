import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HMBTheme {
  static const double padding = 8;
  static const double margin = 8;

  static const HMBColors colors = HMBColors();

  /// padding to separate a page layout from the
  /// thumb menu circle that protudes up into the main
  /// page layout area.
  static const double bottomThumbMenuPadding = 20;
}

class HMBColors {
  const HMBColors();
  static const Color primary = Color(0xFFBB86FC);
  static const Color accent = Color(0xFF03DAC5);

  /// Colors created by creating two lays in gimp
  /// bottom layer is Colors.green.
  /// Top layer is white and then we increase the
  /// top layers opacity to a given percentage
  /// e.g. for [green40] the opacity was 40%.
  static const Color green40 = Color(0xFFb8d5b2);
  static const Color green30 = Color(0xFFa7cc9f);
  static const Color green20 = Color(0xFF94c588);
  static const Color green10 = Color(0xFF7dbb6b);

  /// The background color to be used by all pages.
  static const Color defaultBackground = Colors.black;

  /// The background color of the heading panel on each page.
  static const Color headingBackground = Colors.purple;

  /// the color of most text such as body text.
  static const Color textPrimary = Colors.black;

  /// Used in headings
  static const Color textHeading = Colors.black;

  /// The color of text when used for a fields label.
  static const Color fieldLabel = Colors.purple;

  /// The color of text used for a chip. Some darker
  /// colored chips may need to use the light version
  /// of the chip text.
  static const Color chipTextColor = Colors.black;
  static const Color darkChipText = Colors.white;

  /// List Cards
  static const Color listCardBackgroundSelected =
      Color(0xFF9C27B0); // 0xFFBA68C8); // Colors.purple[300];
  static const Color listCardBackgroundInActive = green20;
  static const Color listCardText = Colors.black;

  /// When displaying an alert this should be used
  /// as the background color for the title.
  static const Color errorBackground = Color(0xFFda6379); // Color(0xCF6679);

  /// When displaying an alert use this as the
  /// color for the title text.
  static const Color errorText = Colors.black;

  /// When displaying an alert use this as the
  /// color for the title text.
  static const Color alertText = Colors.black;

  /// When displaying an alert this should be used
  /// as the background color for the title.
  static const Color alertBackground = Colors.orange;

  /// The color used for most text in the wizard.
  static const Color wizardText = Colors.white;

  /// When displaying an information message
  /// use this as the background for the title.
  static const Color infoBackground = Colors.lightBlue;

  /// The color of the help icon
  static const Color helpIcon = Color(0xFF0000FF); // dark blue

  /// the background color of the main app bar
  static const Color appBarColor = Color(0xFFBB86FC); // Colors.deepPurple;

  /// When a text element needs to stand out from
  /// surrounding text use this color.
  static const Color highlightText = Colors.orange;

  /// colors are based on:
  /// https://material.io/design/color/dark-theme.html#ui-application
  static const Color surface0dp = Color(0xFF121212);
  static const Color surface1dp = Color(0xFF1d1d1d);
  static const Color surface2dp = Color(0xFF222222);
  static const Color surface3dp = Color(0xFF242424);
  static const Color surface4dp = Color(0xFF272727);
  static const Color surface6dp = Color(0xFF2c2c2c);
  static const Color surface8dp = Color(0xFF2d2d2d);
  static const Color surface12dp = Color(0xFF323232);
  static const Color surface16dp = Color(0xFF353535);
  static const Color surface24dp = Color(0xFF373737);
}

enum SurfaceElevation { e0, e1, e2, e3, e4, e6, e8, e12, e16, e24 }

///
/// Creates a Material design surface with a given [elevation].
/// The default [elevation] is 4dp, the default [padding] is
/// defined by [HMBTheme.padding].
///
/// A Surface is just a container using a defined color to give the
/// illusion of an elevation for a dark theme.
///
class Surface extends StatelessWidget {
  const Surface(
      {required this.child,
      super.key,
      this.elevation = SurfaceElevation.e4,
      this.padding});
  final Widget child;
  final SurfaceElevation elevation;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry? usePadding;
    usePadding = padding;

    return Container(
        color: color(elevation), padding: usePadding, child: child);
  }

  static Color color(SurfaceElevation elevation) {
    Color color;

    switch (elevation) {
      case SurfaceElevation.e0:
        color = HMBColors.surface0dp;
        break;
      case SurfaceElevation.e1:
        color = HMBColors.surface1dp;
        break;
      case SurfaceElevation.e2:
        color = HMBColors.surface2dp;
        break;
      case SurfaceElevation.e3:
        color = HMBColors.surface3dp;
        break;
      case SurfaceElevation.e4:
        color = HMBColors.surface4dp;
        break;
      case SurfaceElevation.e6:
        color = HMBColors.surface6dp;
        break;
      case SurfaceElevation.e8:
        color = HMBColors.surface8dp;
        break;
      case SurfaceElevation.e12:
        color = HMBColors.surface12dp;
        break;
      case SurfaceElevation.e16:
        color = HMBColors.surface16dp;
        break;
      case SurfaceElevation.e24:
        color = HMBColors.surface24dp;
        break;
    }
    return color;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<SurfaceElevation>('elevation', elevation))
      ..add(DiagnosticsProperty<EdgeInsetsGeometry?>('padding', padding));
  }
}
