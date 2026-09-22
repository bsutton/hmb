// calendar_view uses Flutter Material types, distinct from material_ui.
// ignore: migrate_design_widgets
import 'package:flutter/material.dart' as flutter;
import 'package:material_ui/material_ui.dart';

/// Gives third-party Flutter Material widgets the same style as material_ui.
///
/// Install above the navigator so dialogs inherit the adapter too. The two
/// libraries have distinct Theme, Material and MaterialLocalizations types.
class HMBMaterialAdapter extends StatelessWidget {
  final Widget child;

  const HMBMaterialAdapter({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    return flutter.Theme(
      data: flutter.ThemeData(
        colorScheme: flutter.ColorScheme.dark(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          primaryContainer: colors.primaryContainer,
          onPrimaryContainer: colors.onPrimaryContainer,
          secondary: colors.secondary,
          onSecondary: colors.onSecondary,
          surface: colors.surface,
          onSurface: colors.onSurface,
          onSurfaceVariant: colors.onSurfaceVariant,
          surfaceContainerLowest: colors.surfaceContainerLowest,
          surfaceContainerLow: colors.surfaceContainerLow,
          surfaceContainer: colors.surfaceContainer,
          surfaceContainerHigh: colors.surfaceContainerHigh,
          surfaceContainerHighest: colors.surfaceContainerHighest,
          outline: colors.outline,
          outlineVariant: colors.outlineVariant,
          error: colors.error,
          onError: colors.onError,
        ),
        scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
        dividerColor: theme.dividerColor,
        textTheme: flutter.TextTheme(
          displayLarge: text.displayLarge,
          displayMedium: text.displayMedium,
          displaySmall: text.displaySmall,
          headlineLarge: text.headlineLarge,
          headlineMedium: text.headlineMedium,
          headlineSmall: text.headlineSmall,
          titleLarge: text.titleLarge,
          titleMedium: text.titleMedium,
          titleSmall: text.titleSmall,
          bodyLarge: text.bodyLarge,
          bodyMedium: text.bodyMedium,
          bodySmall: text.bodySmall,
          labelLarge: text.labelLarge,
          labelMedium: text.labelMedium,
          labelSmall: text.labelSmall,
        ),
        datePickerTheme: flutter.DatePickerThemeData(
          backgroundColor: theme.datePickerTheme.backgroundColor,
          surfaceTintColor: theme.datePickerTheme.surfaceTintColor,
          shape: theme.datePickerTheme.shape,
          headerBackgroundColor: theme.datePickerTheme.headerBackgroundColor,
          headerForegroundColor: theme.datePickerTheme.headerForegroundColor,
        ),
      ),
      child: Localizations.override(
        context: context,
        delegates: const [flutter.DefaultMaterialLocalizations.delegate],
        child: flutter.Material(
          type: flutter.MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}
