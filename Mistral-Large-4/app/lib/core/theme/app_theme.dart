import 'package:flutter/material.dart' hide Typography;
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';
import 'typography.dart';

/// Paper cookbook theme. Warm, flat, hairline rules — no Material flashiness.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Palette.paper,
        colorScheme: const ColorScheme.light(
          primary: Palette.ink,
          secondary: Palette.coral,
          surface: Palette.paper,
          onSurface: Palette.ink,
        ),
        textTheme: GoogleFonts.playfairDisplayTextTheme().apply(
          bodyColor: Palette.ink,
          displayColor: Palette.ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Palette.paper,
          foregroundColor: Palette.ink,
          elevation: 0,
          centerTitle: true,
        ),
        dividerColor: Palette.line,
        checkboxTheme: CheckboxThemeData(
          side: const BorderSide(color: Palette.inkSoft, width: 1.4),
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Palette.teal;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Palette.paper),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Palette.teal;
            return Palette.inkFaint;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Palette.teal.withValues(alpha: 0.35);
            }
            return Palette.line;
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Palette.paper,
          selectedColor: Palette.teal,
          side: const BorderSide(color: Palette.line, width: 1.3),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          labelStyle: Typography.mono(10.5, color: Palette.inkSoft),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Palette.ink,
          contentTextStyle: Typography.mono(11, color: Palette.paper),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Palette.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            side: BorderSide(color: Palette.line),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Palette.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            side: BorderSide(color: Palette.line),
          ),
        ),
      );

  /// Cook mode: dark, full-bleed, high contrast, paper-colored type.
  static ThemeData get cook => ThemeData(
        useMaterial3: false,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.cookBg,
        colorScheme: const ColorScheme.dark(
          primary: Palette.mustard,
          secondary: Palette.coral,
          surface: Palette.cookPanel,
          onSurface: Palette.cookPaper,
        ),
        textTheme: GoogleFonts.playfairDisplayTextTheme(ThemeData.dark().textTheme)
            .apply(
          bodyColor: Palette.cookPaper,
          displayColor: Palette.cookPaper,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Palette.cookPanel,
          contentTextStyle: Typography.mono(11, color: Palette.cookPaper),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
