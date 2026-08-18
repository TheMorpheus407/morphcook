import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VintageColors {
  // Paper & Ink
  static const Color paperBg = Color(0xFFFDFBF7);
  static const Color paperCard = Color(0xFFF6F2EA);
  static const Color paperSurface = Color(0xFFEFE9DE);
  static const Color paperBorder = Color(0xFFDFD7C8);
  static const Color ink = Color(0xFF2E2722);
  static const Color inkLight = Color(0xFF6B6055);
  static const Color inkMuted = Color(0xFF9E9486);

  // Vintage Accents
  static const Color terracotta = Color(0xFFC05C46);
  static const Color sage = Color(0xFF4E6E58);
  static const Color mustard = Color(0xFFD49E4A);
  static const Color plum = Color(0xFF7A4A58);
  static const Color olive = Color(0xFF6E7252);
  static const Color antiqueBlue = Color(0xFF4A6B7E);

  // Dark Cook Mode
  static const Color cookBg = Color(0xFF161412);
  static const Color cookCard = Color(0xFF221F1C);
  static const Color cookBorder = Color(0xFF38332E);
  static const Color cookText = Color(0xFFF4EFEA);
  static const Color cookTextMuted = Color(0xFFA69E94);
  static const Color cookAccent = Color(0xFFE07A5F);
  static const Color cookFlashTeal = Color(0xFF2A9D8F);
}

class VintageTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: VintageColors.paperBg,
      colorScheme: const ColorScheme.light(
        primary: VintageColors.terracotta,
        onPrimary: Colors.white,
        secondary: VintageColors.sage,
        onSecondary: Colors.white,
        surface: VintageColors.paperCard,
        onSurface: VintageColors.ink,
        error: Color(0xFFBA1A1A),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: VintageColors.ink,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: VintageColors.ink,
        ),
        displaySmall: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: VintageColors.ink,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: VintageColors.ink,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: VintageColors.ink,
        ),
        titleMedium: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: VintageColors.ink,
        ),
        bodyLarge: GoogleFonts.ebGaramond(
          fontSize: 17,
          color: VintageColors.ink,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.ebGaramond(
          fontSize: 15,
          color: VintageColors.ink,
          height: 1.4,
        ),
        bodySmall: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: VintageColors.inkLight,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: VintageColors.ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: VintageColors.paperBg,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: VintageColors.ink,
        ),
        iconTheme: const IconThemeData(color: VintageColors.ink),
      ),
      cardTheme: CardThemeData(
        color: VintageColors.paperCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: VintageColors.paperBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: VintageColors.paperBorder,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
