import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NostalgicPalette {
  const NostalgicPalette._();

  static const Color parchment = Color(0xFFF6F1E7);
  static const Color cardStock = Color(0xFFFAF7F0);
  static const Color agedPaper = Color(0xFFEBE3D3);
  static const Color warmSand = Color(0xFFE0D5C1);
  static const Color ink = Color(0xFF26211D);
  static const Color fadedInk = Color(0xFF6E6359);
  static const Color lightInk = Color(0xFF94887B);
  static const Color mutedRule = Color(0xFFC8BFA8);

  static const Color terracotta = Color(0xFFC86D51);
  static const Color sage = Color(0xFF5B7A72);
  static const Color saffron = Color(0xFFD4A359);
  static const Color berry = Color(0xFF9E4B47);

  // Full-bleed dark Cook Mode palette
  static const Color cookDarkBg = Color(0xFF1A1715);
  static const Color cookDarkSurface = Color(0xFF27221F);
  static const Color cookDarkCard = Color(0xFF322C28);
  static const Color cookDarkInk = Color(0xFFF4EDE2);
  static const Color cookDarkMuted = Color(0xFFB3A698);

  // Accessibility timer flash alert colors
  static const Color coralAlert = Color(0xFFE06D53);
  static const Color tealAlert = Color(0xFF4EA89B);
}

class NostalgicTheme {
  const NostalgicTheme._();

  static void ensureOfflineFontsConfigured() {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  static TextStyle serifDisplay({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle fontStyle = FontStyle.italic,
    Color color = NostalgicPalette.ink,
    double height = 1.2,
  }) {
    ensureOfflineFontsConfigured();
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
    );
  }

  static TextStyle serifBody({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle fontStyle = FontStyle.normal,
    Color color = NostalgicPalette.ink,
    double height = 1.45,
  }) {
    ensureOfflineFontsConfigured();
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
    );
  }

  static TextStyle mono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = NostalgicPalette.fadedInk,
    double letterSpacing = 0.4,
    double height = 1.35,
  }) {
    ensureOfflineFontsConfigured();
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle handwritten({
    double fontSize = 19,
    FontWeight fontWeight = FontWeight.w500,
    Color color = NostalgicPalette.fadedInk,
    double height = 1.2,
  }) {
    ensureOfflineFontsConfigured();
    return GoogleFonts.caveat(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static ThemeData get lightTheme {
    ensureOfflineFontsConfigured();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: NostalgicPalette.parchment,
      colorScheme: const ColorScheme.light(
        primary: NostalgicPalette.terracotta,
        onPrimary: NostalgicPalette.cardStock,
        secondary: NostalgicPalette.sage,
        onSecondary: NostalgicPalette.cardStock,
        tertiary: NostalgicPalette.saffron,
        surface: NostalgicPalette.cardStock,
        onSurface: NostalgicPalette.ink,
        surfaceContainerHighest: NostalgicPalette.agedPaper,
        outline: NostalgicPalette.mutedRule,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NostalgicPalette.parchment,
        foregroundColor: NostalgicPalette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: serifDisplay(fontSize: 22),
      ),
      cardTheme: CardThemeData(
        color: NostalgicPalette.cardStock,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: NostalgicPalette.mutedRule, width: 0.8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NostalgicPalette.agedPaper,
        selectedColor: NostalgicPalette.terracotta.withValues(alpha: 0.18),
        disabledColor: NostalgicPalette.agedPaper.withValues(alpha: 0.45),
        side: const BorderSide(color: NostalgicPalette.mutedRule),
        labelStyle: mono(fontSize: 12, color: NostalgicPalette.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      dividerColor: NostalgicPalette.mutedRule,
    );
  }
}
