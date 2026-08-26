/// MorphCook design system — "tumblr-era cookbook": warm paper, ink,
/// terracotta & dusty teal accents, Playfair Display for display,
/// JetBrains Mono for data, Caveat for handwritten accents.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------- palette --
class Palette {
  // paper & ink
  static const Color paper = Color(0xFFF4EEE3); // warm cream
  static const Color paperDeep = Color(0xFFEAE0CC);
  static const Color cardPaper = Color(0xFFF9F4EA);
  static const Color ink = Color(0xFF2E2A24);
  static const Color inkSoft = Color(0xFF5C554A);
  static const Color inkFaint = Color(0xFF8B8172);

  // accents
  static const Color coral = Color(0xFFC65D3B); // terracotta
  static const Color coralSoft = Color(0xFFE4A189);
  static const Color teal = Color(0xFF4E7D74); // dusty teal
  static const Color tealSoft = Color(0xFFA7C4BC);
  static const Color mustard = Color(0xFFC99A3C);
  static const Color sage = Color(0xFF7E9B7A);
  static const Color plum = Color(0xFF7C5A6B);
  static const colors = [
    coral, teal, mustard, sage, plum, coralSoft,
  ];

  static const Color cook = Color(0xFF1C1A17); // cook-mode paper-dark

  static const List<double> stripeAlphas = [1.0, 0.55];
}

// ----------------------------------------------------------------- theme ---
ThemeData buildTheme(Brightness brightness) {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.coral,
    onPrimary: Colors.white,
    secondary: Palette.teal,
    onSecondary: Colors.white,
    surface: Palette.paper,
    onSurface: Palette.ink,
    surfaceContainerHighest: Palette.paperDeep,
    onSurfaceVariant: Palette.inkSoft,
    error: Palette.coral,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    fontFamily: 'JetBrainsMono',
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'PlayfairDisplay',
        fontStyle: FontStyle.italic,
        fontSize: 22,
        color: Palette.ink,
      ),
      iconTheme: IconThemeData(color: Palette.ink),
    ),
    cardTheme: CardThemeData(
      color: Palette.cardPaper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Palette.ink.withValues(alpha: 0.08)),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0x00000000),
      selectedColor: Palette.ink.withValues(alpha: 0.08),
      side: BorderSide(color: Palette.ink.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: TextStyle(fontSize: 13, color: Palette.ink, fontFamily: 'JetBrainsMono'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.cardPaper,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Palette.ink.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Palette.ink.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Palette.coral, width: 1.4),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Palette.ink,
      iconColor: Palette.inkSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.teal : Palette.inkFaint),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Palette.tealSoft
              : Palette.ink.withValues(alpha: 0.12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.coral),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      contentTextStyle: const TextStyle(color: Palette.paper, fontFamily: 'JetBrainsMono'),
    ),
  );
}

/// Convenience typographic styles.
class T {
  static const display = TextStyle(
      fontFamily: 'PlayfairDisplay', fontStyle: FontStyle.italic, fontSize: 30, color: Palette.ink);
  static const h1 = TextStyle(
      fontFamily: 'PlayfairDisplay', fontStyle: FontStyle.italic, fontSize: 26, color: Palette.ink, height: 1.15);
  static const h2 = TextStyle(
      fontFamily: 'PlayfairDisplay', fontStyle: FontStyle.italic, fontSize: 20, color: Palette.ink);
  static const body = TextStyle(fontSize: 15, color: Palette.inkSoft, height: 1.45, fontFamily: 'JetBrainsMono');
  static const caption = TextStyle(fontSize: 12, color: Palette.inkFaint, fontFamily: 'JetBrainsMono', letterSpacing: 0.6);
  static const mono = TextStyle(fontSize: 12, color: Palette.inkSoft, fontFamily: 'JetBrainsMono');
  static const hand = TextStyle(fontFamily: 'Caveat', fontSize: 20, color: Palette.coral, height: 1.1);
  static const section = TextStyle(
      fontFamily: 'JetBrainsMono', fontSize: 12, letterSpacing: 2.2, color: Palette.inkSoft);
}
