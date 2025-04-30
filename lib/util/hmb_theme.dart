import 'package:flutter/material.dart';

class HMBTheme {
  static const double padding = 8;
  static const double margin = 8;

  static const colors = HMBColors();

  /// padding to separate a page layout from the
  /// thumb menu circle that protudes up into the main
  /// page layout area.
  static const double bottomThumbMenuPadding = 20;
}

class HMBColors {
  const HMBColors();
  static const primary = Color(0xFFBB86FC);
  static const accent = Color(0xFF03DAC5);

  /// Colors created by creating two layers in gimp
  /// bottom layer is Colors.green.
  /// Top layer is white and then we increase the
  /// top layers opacity to a given percentage
  /// e.g. for [green40] the opacity was 40%.
  static const green40 = Color(0xFFb8d5b2);
  static const green30 = Color(0xFFa7cc9f);
  static const green20 = Color(0xFF94c588);
  static const green10 = Color(0xFF7dbb6b);

  /// The background color to be used by all pages.
  static const Color defaultBackground = Colors.black;

  /// The background color of the heading panel on each page.
  static const Color headingBackground = Colors.purple;

  /// the color of most text such as body text.
  static const Color textPrimary = Colors.white;

  /// Used in headings
  static const Color textHeading = Colors.black;

  /// The color of text when used for a fields label.
  static const Color fieldLabel = Colors.purple;

  static const Color buttonLabel = Colors.white;

  /// The color of text used for a chip. Some darker
  /// colored chips may need to use the light version
  /// of the chip text.
  static const Color chipTextColor = Colors.black;
  static const Color darkChipText = Colors.white;

  static const Color dropboxArrow = Colors.white;

  static const Color inputDecoration = Colors.white;

  /// List Cards
  static const listCardBackgroundSelected = Color(
    0xFF9C27B0,
  ); // 0xFFBA68C8); // Colors.purple[300];
  static const Color listCardBackgroundInActive = green20;
  static const Color listCardText = Colors.black;

  /// When displaying an alert this should be used
  /// as the background color for the title.
  static const errorBackground = Color(0xFFda6379); // Color(0xCF6679);

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
  static const helpIcon = Color(0xFF0000FF); // dark blue

  /// the background color of the main app bar
  static const appBarColor = Color(0xFFBB86FC); // Colors.deepPurple;

  /// When a text element needs to stand out from
  /// surrounding text use this color.
  static const Color highlightText = Colors.orange;

  /// colors are based on:
  /// https://material.io/design/color/dark-theme.html#ui-application

  static const surface0dp = Color(0xFF000000); // Pure black
  static const surface1dp = Color(0xFF121212);
  static const surface2dp = Color(0xFF1d1d1d);
  static const surface3dp = Color(0xFF222222);
  static const surface4dp = Color(0xFF242424);
  static const surface6dp = Color(0xFF272727);
  static const surface8dp = Color(0xFF2c2c2c);
  static const surface12dp = Color(0xFF2d2d2d);
  static const surface16dp = Color(0xFF323232);
  static const surface24dp = Color(0xFF353535);
  static const surface32dp = Color(0xFF373737);
}
