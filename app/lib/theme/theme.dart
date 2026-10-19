import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildKorramTheme() {
  const scheme = ColorScheme.dark(
    primary: KColors.coral,
    onPrimary: KColors.onCoral,
    secondary: KColors.lilac,
    tertiary: KColors.mint,
    error: KColors.danger,
    surface: KColors.surface,
    onSurface: KColors.text,
    onSurfaceVariant: KColors.muted,
    outline: KColors.line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: KColors.background,
    fontFamily: KFonts.body,
    textTheme: const TextTheme(
      displayLarge: KType.hero,
      headlineLarge: KType.title,
      titleLarge: KType.cardTitle,
      bodyLarge: KType.bodyLarge,
      bodyMedium: KType.body,
      bodySmall: KType.small,
      labelLarge: KType.button,
      labelSmall: KType.label,
    ).apply(bodyColor: KColors.text, displayColor: KColors.text),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KColors.coral,
        foregroundColor: KColors.onCoral,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.xl)),
        textStyle: KType.buttonLarge,
        disabledBackgroundColor: KColors.surface2,
        disabledForegroundColor: KColors.disabledText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: KColors.surface,
        foregroundColor: KColors.text,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: KColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.lg)),
        textStyle: KType.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: KType.input.copyWith(color: KColors.disabledText),
      border: _fieldBorder(KColors.line),
      enabledBorder: _fieldBorder(KColors.line),
      focusedBorder: _fieldBorder(KColors.coral),
      errorBorder: _fieldBorder(KColors.danger),
      focusedErrorBorder: _fieldBorder(KColors.danger),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: KColors.coral),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? KColors.coral : null,
      ),
      checkColor: WidgetStateProperty.all(KColors.onCoral),
      side: const BorderSide(color: KColors.muted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KColors.surface2,
      contentTextStyle: KType.body.copyWith(color: KColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(KRadius.lg),
  borderSide: BorderSide(color: color),
);
