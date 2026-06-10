import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: MCColors.cream,
    colorScheme: const ColorScheme.light(
      primary: MCColors.coral,
      onPrimary: MCColors.cream,
      secondary: MCColors.teal,
      onSecondary: MCColors.cream,
      surface: MCColors.cream,
      onSurface: MCColors.ink,
      surfaceTint: MCColors.paper,
      outline: MCColors.inkWhisper,
    ),
    iconTheme: const IconThemeData(color: MCColors.inkSoft, size: 20),
    textTheme: TextTheme(
      displayLarge: MCTypography.display(size: 56),
      displayMedium: MCTypography.display(size: 44),
      displaySmall: MCTypography.display(size: 32),
      headlineLarge: MCTypography.title(size: 30),
      headlineMedium: MCTypography.title(size: 24),
      headlineSmall: MCTypography.title(size: 20),
      titleLarge: MCTypography.title(size: 18, weight: FontWeight.w600),
      titleMedium: MCTypography.title(size: 16),
      titleSmall: MCTypography.title(size: 14),
      bodyLarge: MCTypography.body(size: 15.5),
      bodyMedium: MCTypography.body(size: 14),
      bodySmall: MCTypography.body(size: 12.5, color: MCColors.inkSoft),
      labelLarge: MCTypography.eyebrow(),
      labelMedium: MCTypography.caption(),
      labelSmall: MCTypography.caption(),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: MCColors.cream,
      foregroundColor: MCColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: MCTypography.title(size: 20),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MCColors.paper,
      selectedItemColor: MCColors.coral,
      unselectedItemColor: MCColors.inkFaded,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    dividerTheme: const DividerThemeData(
      color: MCColors.paperDark,
      thickness: 0.6,
      space: 24,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MCColors.polaroid,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: MCTypography.body(color: MCColors.inkFaded),
      hintStyle: MCTypography.body(color: MCColors.inkWhisper),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: MCColors.paperDark, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: MCColors.paperDark, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: MCColors.ink, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MCColors.ink,
        foregroundColor: MCColors.cream,
        elevation: 0,
        textStyle: MCTypography.body(weight: FontWeight.w600, color: MCColors.cream),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MCColors.ink,
        side: const BorderSide(color: MCColors.ink, width: 0.8),
        textStyle: MCTypography.body(weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MCColors.ink,
        textStyle: MCTypography.body(weight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MCColors.polaroid,
      selectedColor: MCColors.ink,
      secondarySelectedColor: MCColors.coral,
      labelStyle: MCTypography.body(size: 12.5),
      secondaryLabelStyle: MCTypography.body(size: 12.5, color: MCColors.cream),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: MCColors.paperDark, width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MCColors.ink,
      contentTextStyle: MCTypography.body(color: MCColors.cream),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MCColors.polaroid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
    splashColor: MCColors.paperDark,
    highlightColor: MCColors.paper,
  );
}

ThemeData buildCookModeTheme() {
  return ThemeData.dark(useMaterial3: true).copyWith(
    scaffoldBackgroundColor: MCColors.cookInk,
    colorScheme: const ColorScheme.dark(
      primary: MCColors.coral,
      onPrimary: MCColors.cookCream,
      secondary: MCColors.teal,
      onSecondary: MCColors.cookCream,
      surface: MCColors.cookInk,
      onSurface: MCColors.cookCream,
    ),
    textTheme: TextTheme(
      displayLarge: MCTypography.display(size: 56, color: MCColors.cookCream),
      displayMedium: MCTypography.display(size: 44, color: MCColors.cookCream),
      headlineMedium: MCTypography.title(size: 30, color: MCColors.cookCream),
      bodyLarge: MCTypography.body(size: 22, color: MCColors.cookCream, height: 1.5),
      bodyMedium: MCTypography.body(size: 18, color: MCColors.cookCream, height: 1.5),
      labelLarge: MCTypography.eyebrow(color: MCColors.cookCream),
    ),
  );
}
