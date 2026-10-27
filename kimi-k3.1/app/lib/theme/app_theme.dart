import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const paper = Color(0xfff3eee3);
  static const paperLight = Color(0xfffbf8f1);
  static const ink = Color(0xff26332f);
  static const muted = Color(0xff6c746d);
  static const coral = Color(0xffc97867);
  static const teal = Color(0xff3f756c);
  static const gold = Color(0xffd5b46b);
  static const dark = Color(0xff14231f);
  static const darkPaper = Color(0xffe8e3d7);
}

ThemeData buildAppTheme() {
  const ink = AppColors.ink;
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = base.textTheme.copyWith(
    displayLarge: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 44,
      height: 1.04,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      color: ink,
      letterSpacing: -1.4,
    ),
    displaySmall: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 34,
      height: 1.08,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      color: ink,
      letterSpacing: -0.7,
    ),
    headlineMedium: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 27,
      height: 1.15,
      fontStyle: FontStyle.italic,
      color: ink,
    ),
    headlineSmall: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 23,
      height: 1.2,
      fontStyle: FontStyle.italic,
      color: ink,
    ),
    titleLarge: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyLarge: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 17,
      height: 1.55,
      color: ink,
    ),
    bodyMedium: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 15,
      height: 1.5,
      color: ink,
    ),
    bodySmall: const TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 13,
      height: 1.45,
      color: AppColors.muted,
    ),
    labelLarge: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: ink,
    ),
    labelMedium: const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 10,
      height: 1.4,
      letterSpacing: 0.8,
      color: AppColors.muted,
    ),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.paperLight,
      secondary: AppColors.teal,
      onSecondary: AppColors.paperLight,
      tertiary: AppColors.coral,
      surface: AppColors.paperLight,
      onSurface: ink,
      onSurfaceVariant: AppColors.muted,
      outline: Color(0xffaaa698),
      error: Color(0xff9e3f35),
    ),
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paperLight,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: ink, width: 0.9),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.teal,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: ink),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.teal.withValues(alpha: 0.13),
      disabledColor: AppColors.muted.withValues(alpha: 0.07),
      side: const BorderSide(color: Color(0xffaaa698), width: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      labelStyle: textTheme.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paperLight.withValues(alpha: 0.7),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xffaaa698)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xffaaa698)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.teal,
      thumbColor: AppColors.teal,
      inactiveTrackColor: AppColors.teal.withValues(alpha: 0.18),
      overlayColor: AppColors.teal.withValues(alpha: 0.1),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.teal,
      linearTrackColor: Color(0xffd9d3c5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.paperLight,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ink,
      unselectedLabelColor: AppColors.muted,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
      indicatorColor: AppColors.coral,
      dividerColor: Colors.transparent,
    ),
  );
}

extension HandwrittenText on TextStyle {
  TextStyle get handwritten => copyWith(
    fontFamily: 'Caveat',
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
    fontSize: 25,
    height: 1.1,
  );
}
