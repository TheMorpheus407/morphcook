import 'package:flutter/material.dart';

class InkPalette {
  final Color linen;
  final Color linenDeep;
  final Color card;
  final Color walnut;
  final Color walnutSoft;
  final Color walnutFaint;
  final Color sage;
  final Color clay;
  final Color gold;
  final Color teal;
  final Color coral;
  final Color line;
  final Color grain;
  final Brightness brightness;

  const InkPalette({
    required this.linen,
    required this.linenDeep,
    required this.card,
    required this.walnut,
    required this.walnutSoft,
    required this.walnutFaint,
    required this.sage,
    required this.clay,
    required this.gold,
    required this.teal,
    required this.coral,
    required this.line,
    required this.grain,
    required this.brightness,
  });

  static const night = Color(0xFF1A1612);
  static const cream = Color(0xFFF4EBDD);

  static const morning = InkPalette(
    linen: Color(0xFFF4EBDD),
    linenDeep: Color(0xFFE8DCC8),
    card: Color(0xFFFBF6EC),
    walnut: Color(0xFF3B3228),
    walnutSoft: Color(0xFF6B5E50),
    walnutFaint: Color(0xFF8A7A68),
    sage: Color(0xFF7D8B72),
    clay: Color(0xFFC27A5C),
    gold: Color(0xFFC9A96A),
    teal: Color(0xFF5F8A86),
    coral: Color(0xFFE07A5F),
    line: Color(0xFFD4C6B0),
    grain: Color(0x145B4A33),
    brightness: Brightness.light,
  );

  static const evening = InkPalette(
    linen: night,
    linenDeep: Color(0xFF120F0C),
    card: Color(0xFF241F19),
    walnut: cream,
    walnutSoft: Color(0xFFC4B6A2),
    walnutFaint: Color(0xFF8E8272),
    sage: Color(0xFF9AAB8E),
    clay: Color(0xFFD49276),
    gold: Color(0xFFD4B67A),
    teal: Color(0xFF7EAAA6),
    coral: Color(0xFFEB9078),
    line: Color(0xFF3A3229),
    grain: Color(0x14F4EBDD),
    brightness: Brightness.dark,
  );
}

class LedgerTheme {
  static const playfair = 'Playfair Display';
  static const mono = 'JetBrains Mono';
  static const caveat = 'Caveat';

  static ThemeData of(InkPalette p) {
    final base = p.brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: p.linen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.clay,
        brightness: p.brightness,
        surface: p.linen,
        onSurface: p.walnut,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: playfair,
          fontStyle: FontStyle.italic,
          fontSize: 44,
          height: 1.05,
          color: p.walnut,
          fontWeight: FontWeight.w400,
        ),
        displayMedium: TextStyle(
          fontFamily: playfair,
          fontStyle: FontStyle.italic,
          fontSize: 32,
          height: 1.1,
          color: p.walnut,
        ),
        headlineMedium: TextStyle(
          fontFamily: playfair,
          fontStyle: FontStyle.italic,
          fontSize: 24,
          height: 1.15,
          color: p.walnut,
        ),
        titleMedium: TextStyle(
          fontFamily: playfair,
          fontSize: 18,
          color: p.walnut,
        ),
        bodyLarge: TextStyle(
          fontFamily: playfair,
          fontSize: 16,
          height: 1.45,
          color: p.walnut,
        ),
        bodyMedium: TextStyle(
          fontFamily: playfair,
          fontSize: 15,
          height: 1.45,
          color: p.walnutSoft,
        ),
        labelSmall: TextStyle(
          fontFamily: mono,
          fontSize: 11,
          letterSpacing: 0.6,
          color: p.walnutFaint,
        ),
        labelLarge: TextStyle(
          fontFamily: mono,
          fontSize: 12,
          letterSpacing: 0.4,
          color: p.walnutSoft,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.linen,
        foregroundColor: p.walnut,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerColor: p.line,
      splashFactory: InkRipple.splashFactory,
    );
  }
}

class LedgerScope extends InheritedWidget {
  final InkPalette palette;
  final bool reduceMotion;

  const LedgerScope({
    super.key,
    required this.palette,
    required this.reduceMotion,
    required super.child,
  });

  static LedgerScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LedgerScope>()!;

  static InkPalette colors(BuildContext context) => of(context).palette;

  Duration motion(BuildContext context, Duration normal) =>
      of(context).reduceMotion ? Duration.zero : normal;

  @override
  bool updateShouldNotify(LedgerScope oldWidget) =>
      palette != oldWidget.palette || reduceMotion != oldWidget.reduceMotion;
}
