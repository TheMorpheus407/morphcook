import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Type ramp: Playfair Display for display (italic, lowercase),
/// JetBrains Mono for metadata and small-caps, Caveat for handwritten accents.
class MorphType {
  static TextStyle display({double size = 38, FontStyle? style}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontStyle: style ?? FontStyle.italic,
        fontWeight: FontWeight.w500,
        color: MorphColors.ink,
        height: 1.05,
        letterSpacing: -0.4,
      );

  static TextStyle headline({double size = 24}) => GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: MorphColors.ink,
        height: 1.15,
      );

  static TextStyle body({double size = 15, Color? color}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? MorphColors.inkSoft,
        height: 1.55,
      );

  static TextStyle mono({double size = 11, Color? color, double? spacing}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color ?? MorphColors.inkMuted,
        letterSpacing: spacing ?? 1.6,
        fontWeight: FontWeight.w500,
      );

  static TextStyle smallCaps({double size = 10, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color ?? MorphColors.inkMuted,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w600,
      );

  static TextStyle hand({double size = 22, Color? color}) => GoogleFonts.caveat(
        fontSize: size,
        color: color ?? MorphColors.ink,
        height: 1.0,
      );
}

class MorphTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: MorphColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MorphColors.coral,
        primary: MorphColors.coral,
        secondary: MorphColors.teal,
        surface: MorphColors.paper,
        onSurface: MorphColors.ink,
        brightness: Brightness.light,
      ),
      textTheme: TextTheme(
        displayLarge: MorphType.display(size: 44),
        displayMedium: MorphType.display(size: 36),
        displaySmall: MorphType.display(size: 28),
        headlineMedium: MorphType.headline(size: 24),
        headlineSmall: MorphType.headline(size: 20),
        titleLarge: MorphType.headline(size: 18),
        bodyLarge: MorphType.body(size: 16),
        bodyMedium: MorphType.body(size: 15),
        bodySmall: MorphType.body(size: 13, color: MorphColors.inkMuted),
        labelLarge: MorphType.mono(size: 12),
        labelMedium: MorphType.mono(size: 11),
        labelSmall: MorphType.smallCaps(size: 10),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: MorphColors.paper,
        elevation: 0,
        centerTitle: true,
        foregroundColor: MorphColors.ink,
        titleTextStyle: MorphType.smallCaps(size: 11, color: MorphColors.ink),
        iconTheme: IconThemeData(color: MorphColors.ink, size: 22),
      ),
      iconTheme: IconThemeData(color: MorphColors.inkSoft, size: 20),
      dividerColor: MorphColors.inkFaint,
      splashColor: MorphColors.paperShadow.withValues(alpha: 0.4),
      highlightColor: MorphColors.paperShadow.withValues(alpha: 0.25),
      inputDecorationTheme: InputDecorationTheme(
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: MorphColors.inkFaint),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: MorphColors.inkFaint),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: MorphColors.ink, width: 1.5),
        ),
        labelStyle: MorphType.mono(size: 11),
        hintStyle: MorphType.body(size: 15, color: MorphColors.inkFaint),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? MorphColors.coral : MorphColors.paperDeep),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? MorphColors.coral.withValues(alpha: 0.3)
                : MorphColors.paperShadow),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: MorphColors.inkMuted, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? MorphColors.ink : MorphColors.paper),
        checkColor: WidgetStateProperty.all(MorphColors.paper),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
      ),
    );
  }
}
