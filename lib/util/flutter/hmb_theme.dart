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

import 'package:material_ui/material_ui.dart';

class HMBTheme {
  static const double padding = 8;
  static const double margin = 8;

  static const marginInset = EdgeInsets.all(margin);

  static const colors = HMBColors();

  static const double cornerRadius = 8;
  static const double controlRadius = 6;
  static const double sectionPadding = 12;

  static const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
    side: BorderSide(color: HMBColors.outline),
  );

  static const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
  );

  static BoxDecoration surfaceDecoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(cornerRadius),
    border: Border.all(color: HMBColors.outline),
  );

  /// Shared application style: charcoal panels and lavender actions.
  /// Keep touch targets generous even when the visible controls are compact.
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      onPrimary: HMBColors.onPrimary,
      primaryContainer: HMBColors.primaryContainer,
      onPrimaryContainer: HMBColors.primary,
      secondary: HMBColors.primary,
      onSecondary: HMBColors.onPrimary,
      surface: HMBColors.surface4dp,
      surfaceContainerLowest: HMBColors.defaultBackground,
      surfaceContainerLow: HMBColors.surface2dp,
      surfaceContainer: HMBColors.surface4dp,
      surfaceContainerHigh: HMBColors.surface8dp,
      surfaceContainerHighest: HMBColors.surface12dp,
      onSurface: HMBColors.textPrimary,
      onSurfaceVariant: HMBColors.textSecondary,
      outline: HMBColors.outline,
      outlineVariant: HMBColors.outline,
      error: HMBColors.errorBackground,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HMBColors.defaultBackground,
      visualDensity: VisualDensity.standard,
    );
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
      borderSide: BorderSide(color: HMBColors.fieldOutline),
    );
    final textTheme = base.textTheme.copyWith(
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: HMBColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: HMBColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: HMBColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.4,
        color: HMBColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: HMBColors.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: HMBColors.textSecondary,
      ),
    );
    return base.copyWith(
      textTheme: textTheme,
      dividerColor: HMBColors.outline,
      dividerTheme: const DividerThemeData(
        color: HMBColors.outline,
        thickness: 1,
        space: 16,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: HMBColors.defaultBackground,
        foregroundColor: HMBColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: HMBColors.surface4dp,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
        margin: EdgeInsets.symmetric(vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HMBColors.primary,
          foregroundColor: HMBColors.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HMBColors.primary,
          side: const BorderSide(color: HMBColors.primary),
          minimumSize: const Size(48, 40),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HMBColors.primary,
          minimumSize: const Size(48, 40),
          shape: controlShape,
        ),
      ),
      iconTheme: const IconThemeData(color: HMBColors.textSecondary, size: 20),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: HMBColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HMBColors.surface3dp,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border.copyWith(
          borderSide: const BorderSide(color: HMBColors.outline),
        ),
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: HMBColors.primary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: HMBColors.errorBackground),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(
            color: HMBColors.errorBackground,
            width: 2,
          ),
        ),
        labelStyle: const TextStyle(color: HMBColors.textSecondary),
        hintStyle: const TextStyle(color: HMBColors.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HMBColors.surface4dp,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HMBColors.surface4dp,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HMBColors.surface8dp,
        selectedColor: HMBColors.primaryContainer,
        side: BorderSide.none,
        shape: controlShape,
        labelStyle: textTheme.bodySmall?.copyWith(color: HMBColors.textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: HMBColors.surface4dp,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        textStyle: textTheme.bodyMedium,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: HMBColors.surface4dp,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        headerBackgroundColor: HMBColors.surface4dp,
        headerForegroundColor: HMBColors.textPrimary,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: HMBColors.surface4dp,
        shape: cardShape,
        dialBackgroundColor: HMBColors.surface8dp,
        hourMinuteColor: HMBColors.primaryContainer,
        hourMinuteTextColor: HMBColors.primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HMBColors.primary,
        foregroundColor: HMBColors.onPrimary,
        elevation: 0,
        shape: controlShape,
      ),
      toggleButtonsTheme: const ToggleButtonsThemeData(
        color: HMBColors.textSecondary,
        selectedColor: HMBColors.primary,
        fillColor: HMBColors.primaryContainer,
        borderColor: HMBColors.outline,
        selectedBorderColor: HMBColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: HMBColors.primary,
        unselectedLabelColor: HMBColors.textSecondary,
        indicatorColor: HMBColors.primary,
        dividerColor: HMBColors.outline,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: HMBColors.surface8dp,
        actionTextColor: HMBColors.primary,
        contentTextStyle: TextStyle(color: HMBColors.textPrimary),
      ),
    );
  }

  /// padding to separate a page layout from the
  /// thumb menu circle that protudes up into the main
  /// page layout area.
  static const double bottomThumbMenuPadding = 20;
}

class HMBColors {
  static const primary = Color(0xFFBB86FC);
  static const Color accent = primary;
  static const onPrimary = Color(0xFF241331);
  static const primaryContainer = Color(0xFF3D2E51);
  static const outline = Color(0xFF414145);
  static const fieldOutline = Color(0xFF929098);
  static const textSecondary = Color(0xFFB9B7BE);
  static const success = Color(0xFF8DCEA1);
  static const warning = Color(0xFFFFC477);
  static const warningContainer = Color(0xFF493B25);

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
  static const defaultBackground = Color(0xFF121214);

  /// The background color of the heading panel on each page.
  static const Color headingBackground = surface4dp;

  /// the color of most text such as body text.
  static const textPrimary = Color(0xFFF1EFF4);

  /// Used in headings
  static const Color textHeading = textPrimary;

  /// The color of text when used for a fields label.
  static const Color fieldLabel = textSecondary;

  static const Color buttonLabel = onPrimary;

  /// The color of text used for a chip. Some darker
  /// colored chips may need to use the light version
  /// of the chip text.
  static const Color chipTextColor = Colors.black;
  static const Color darkChipText = Colors.white;

  static const Color dropboxArrow = Colors.white;

  static const Color inputDecoration = Colors.white;

  /// List Cards
  static const listCardBackgroundSelected = Color.fromARGB(
    255,
    169,
    85,
    184,
  ); // 0xFFBA68C8); // Colors.purple[300];
  static const Color listCardBackgroundInActive = green20;
  static const Color listCardText = textPrimary;

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
  static const Color appBarColor = defaultBackground;

  /// When a text element needs to stand out from
  /// surrounding text use this color.
  static const Color highlightText = Colors.orange;

  /// colors are based on:
  /// https://material.io/design/color/dark-theme.html#ui-application

  static const Color surface0dp = defaultBackground;
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
  const HMBColors();
}
